# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authn::SyncScimGroupMembersWorker, feature_category: :system_access do
  let_it_be(:user1) { create(:user) }
  let_it_be(:user2) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:another_group) { create(:group) }
  let_it_be(:scim_group_uid) { SecureRandom.uuid }

  let_it_be(:saml_group_link) do
    create(:saml_group_link,
      group: group,
      saml_group_name: 'engineering',
      scim_group_uid: scim_group_uid,
      access_level: Gitlab::Access::DEVELOPER)
  end

  let_it_be(:another_saml_group_link) do
    create(:saml_group_link,
      group: another_group,
      saml_group_name: 'engineering',
      scim_group_uid: scim_group_uid,
      access_level: Gitlab::Access::DEVELOPER)
  end

  it 'logs all arguments' do
    expect(described_class.loggable_arguments).to include(0, 1, 2)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [scim_group_uid, [user1.id], 'add'] }
  end

  describe '#perform' do
    subject(:worker) { described_class.new }

    let(:user_ids) { [user1.id, user2.id] }

    context 'with add operation' do
      it 'adds the users to all groups' do
        expect(group.users).not_to include(user1, user2)
        expect(another_group.users).not_to include(user1, user2)

        worker.perform(scim_group_uid, user_ids, 'add')

        group.reload
        another_group.reload

        expect(group.users).to include(user1, user2)
        expect(another_group.users).to include(user1, user2)
      end

      context 'with multiple group links having different access levels' do
        let_it_be(:maintainer_link) do
          create(:saml_group_link,
            group: group,
            saml_group_name: 'engineering-leads',
            scim_group_uid: scim_group_uid,
            access_level: Gitlab::Access::MAINTAINER)
        end

        it 'adds users with the highest access level from available links' do
          expect(SamlGroupLink.by_scim_group_uid(scim_group_uid).map(&:access_level))
            .to contain_exactly(Gitlab::Access::DEVELOPER, Gitlab::Access::DEVELOPER, Gitlab::Access::MAINTAINER)

          worker.perform(scim_group_uid, [user1.id], 'add')

          member = group.members.find_by(user_id: user1.id)
          expect(member.access_level).to eq(maintainer_link.access_level)
        end
      end

      context 'when a user is already a member' do
        before do
          group.add_member(user1, Gitlab::Access::DEVELOPER)
        end

        it 'only adds the non-member user and keeps the existing user intact' do
          expect(group.member?(user1)).to be_truthy
          expect(group.member?(user2)).to be_falsey

          worker.perform(scim_group_uid, user_ids, 'add')

          expect(group.users).to include(user1, user2)
        end

        it 'does not downgrade existing higher access level' do
          group.add_member(user1, Gitlab::Access::MAINTAINER)

          worker.perform(scim_group_uid, [user1.id], 'add')

          member = group.members.find_by(user_id: user1.id)
          expect(member.access_level).to eq(Gitlab::Access::MAINTAINER)
        end

        context 'when another group link with higher access exists' do
          let_it_be(:higher_access_link) do
            create(:saml_group_link,
              group: group,
              saml_group_name: 'engineering-leads',
              scim_group_uid: scim_group_uid,
              access_level: Gitlab::Access::MAINTAINER)
          end

          it 'upgrades existing lower access level to match the higher access link' do
            expect(higher_access_link.access_level).to eq(Gitlab::Access::MAINTAINER)

            worker.perform(scim_group_uid, [user1.id], 'add')

            member = group.members.find_by(user_id: user1.id)
            expect(member.access_level).to eq(higher_access_link.access_level)
          end
        end
      end

      context 'with BSO (Block Seat Overages) enabled' do
        before do
          stub_feature_flags(bso_minimal_access_fallback: true)
          stub_licensed_features(minimal_access_role: true)
        end

        subject(:execute_worker) { worker.perform(scim_group_uid, [user1.id], 'add') }

        context 'without available seats' do
          before do
            allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
              .to receive_messages(
                block_seat_overages?: true,
                seats_available_for?: false
              )
          end

          it 'adds users with MINIMAL_ACCESS instead of the desired access level' do
            execute_worker

            member = group.all_group_members.find_by(user_id: user1.id)
            expect(member.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
          end

          it 'tracks minimal access provisioning for all groups linked to the SCIM group',
            :saas, :clean_gitlab_redis_shared_state, :freeze_time do
            execute_worker

            ::Gitlab::Redis::SharedState.with do |redis|
              current_date = Date.current.iso8601
              user_key = "seat_aware_provisioning:group:#{group.id}:{#{current_date}}"
              another_user_key = "seat_aware_provisioning:group:#{another_group.id}:{#{current_date}}"
              root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

              expect(redis.sismember(user_key, user1.id.to_s)).to be true
              expect(redis.sismember(another_user_key, user1.id.to_s)).to be true
              expect(redis.sismember(root_groups_key, group.root_ancestor.id.to_s)).to be true
              expect(redis.sismember(root_groups_key, another_group.root_ancestor.id.to_s)).to be true
            end
          end

          it 'audits minimal access role adjustment' do
            execute_worker

            group_audit_event = AuditEventReader.find_by(
              target_id: user1.id, entity_type: 'Group', entity_id: group.id)
            another_group_audit_event = AuditEventReader.find_by(
              target_id: user1.id, entity_type: 'Group', entity_id: another_group.id)

            expect(group_audit_event.details[:user_id]).to eq(user1.id)
            expect(group_audit_event.details[:requested_access_level]).to eq(Gitlab::Access::DEVELOPER)
            expect(group_audit_event.details[:scim_group_uid]).to eq(scim_group_uid)

            expect(another_group_audit_event.details[:user_id]).to eq(user1.id)
            expect(another_group_audit_event.details[:requested_access_level]).to eq(Gitlab::Access::DEVELOPER)
            expect(another_group_audit_event.details[:scim_group_uid]).to eq(scim_group_uid)
          end

          it 'applies BSO adjustment to all groups linked to the SCIM group' do
            execute_worker

            group_member = group.all_group_members.find_by(user_id: user1.id)
            another_group_member = another_group.all_group_members.find_by(user_id: user1.id)

            expect(group_member.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
            expect(another_group_member.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
          end

          it 'logs BSO adjustment when access level is downgraded' do
            expect(Gitlab::AppLogger).to receive(:info).with(
              hash_including(
                message: 'Group membership access level adjusted due to BSO seat limits',
                group_id: group.id,
                group_path: group.full_path,
                user_id: user1.id,
                requested_access_level: Gitlab::Access::DEVELOPER,
                adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
                feature_flag: 'bso_minimal_access_fallback',
                scim_group_uid: scim_group_uid
              )
            )

            expect(Gitlab::AppLogger).to receive(:info).with(
              hash_including(
                message: 'Group membership access level adjusted due to BSO seat limits',
                group_id: another_group.id,
                group_path: another_group.full_path,
                user_id: user1.id,
                requested_access_level: Gitlab::Access::DEVELOPER,
                adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
                feature_flag: 'bso_minimal_access_fallback',
                scim_group_uid: scim_group_uid
              )
            )

            execute_worker
          end
        end

        context 'with available seats' do
          before do
            allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
              .to receive_messages(
                block_seat_overages?: true,
                seats_available_for?: true
              )
          end

          it 'adds users with the original desired access level' do
            execute_worker

            member = group.members.find_by(user_id: user1.id)
            expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
          end

          it 'does not log BSO adjustment' do
            expect(Gitlab::AppLogger).not_to receive(:info).with(
              hash_including(message: 'Group membership access level adjusted due to BSO seat limits')
            )

            execute_worker
          end

          it 'does not track minimal access provisioning for groups linked to the SCIM group',
            :saas, :clean_gitlab_redis_shared_state, :freeze_time do
            execute_worker

            ::Gitlab::Redis::SharedState.with do |redis|
              current_date = Date.current.iso8601
              users_key = "seat_aware_provisioning:group:#{group.id}:{#{current_date}}"
              another_users_key = "seat_aware_provisioning:group:#{another_group.id}:{#{current_date}}"
              root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

              expect(redis.sismember(users_key, user1.id.to_s)).to be false
              expect(redis.sismember(another_users_key, user1.id.to_s)).to be false
              expect(redis.sismember(root_groups_key, group.root_ancestor.id.to_s)).to be false
              expect(redis.sismember(root_groups_key, another_group.root_ancestor.id.to_s)).to be false
            end
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(bso_minimal_access_fallback: false)
          end

          it 'adds users with the original access level (bypasses BSO)' do
            execute_worker

            member = group.members.find_by(user_id: user1.id)
            expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
          end
        end

        context 'when BSO is not enabled' do
          before do
            allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
              .to receive(:block_seat_overages?).and_return(false)
          end

          it 'adds users with the original access level' do
            execute_worker

            member = group.members.find_by(user_id: user1.id)
            expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
          end
        end
      end
    end

    context 'with remove operation' do
      before do
        group.add_member(user1, Gitlab::Access::DEVELOPER)
        group.add_member(user2, Gitlab::Access::DEVELOPER)
        another_group.add_member(user1, Gitlab::Access::DEVELOPER)
        another_group.add_member(user2, Gitlab::Access::DEVELOPER)
      end

      it 'removes the users from all groups' do
        expect(group.users).to include(user1, user2)
        expect(another_group.users).to include(user1, user2)

        worker.perform(scim_group_uid, user_ids, 'remove')

        group.reload
        another_group.reload

        expect(group.users).not_to include(user1, user2)
        expect(another_group.users).not_to include(user1, user2)
      end

      context 'with subgroup memberships' do
        let_it_be(:subgroup) { create(:group, parent: group) }

        before do
          subgroup.add_member(user1, Gitlab::Access::DEVELOPER)
        end

        it 'preserves subgroup memberships' do
          expect(subgroup.member?(user1)).to be_truthy

          worker.perform(scim_group_uid, [user1.id], 'remove')

          expect(group.member?(user1)).to be_falsey
          expect(subgroup.member?(user1)).to be_truthy
        end
      end

      context 'with non-existent user IDs' do
        it 'handles non-existent user IDs' do
          expect { worker.perform(scim_group_uid, [non_existing_record_id], 'remove') }
            .not_to change { [group.members.count, another_group.members.count] }
        end
      end
    end

    context 'with replace operation' do
      let_it_be(:user3) { create(:user) }

      before do
        create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid)
        create(:scim_group_membership, user: user2, scim_group_uid: scim_group_uid)

        group.add_member(user1, Gitlab::Access::DEVELOPER)
        group.add_member(user2, Gitlab::Access::DEVELOPER)
      end

      it 'replaces all members (removes user1, keeps user2, adds user3)' do
        worker.perform(scim_group_uid, [user2.id, user3.id], 'replace')

        expect(Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid).map(&:user_id))
          .to match_array([user2.id, user3.id])

        group.reload
        group_users = group.users

        expect(group_users.include?(user1)).to be_falsey
        expect(group_users.include?(user2)).to be_truthy
        expect(group_users.include?(user3)).to be_truthy
      end

      context 'when user being removed belongs to multiple SCIM groups' do
        let_it_be(:another_scim_group_uid) { SecureRandom.uuid }
        let_it_be(:another_group_for_replace) { create(:group) }
        let_it_be(:another_group_link_for_replace) do
          create(:saml_group_link, group: another_group_for_replace, scim_group_uid: another_scim_group_uid)
        end

        before do
          create(:scim_group_membership, user: user1, scim_group_uid: another_scim_group_uid)
          another_group_for_replace.add_member(user1, Gitlab::Access::DEVELOPER)

          sync_service_double = instance_double(Groups::SyncService)
          allow(Groups::SyncService).to receive(:new).and_return(sync_service_double)
          allow(sync_service_double).to receive(:execute)
        end

        it 'preserves group membership for users who belong to other SCIM groups' do
          worker.perform(scim_group_uid, [user3.id], 'replace')

          expect(Groups::SyncService).to have_received(:new).with(
            group,
            user1,
            hash_including(
              group_links: [another_group_link_for_replace],
              manage_group_ids: [group.id]
            )
          )

          expect(Groups::SyncService).to have_received(:new).with(
            group,
            user2,
            hash_including(
              group_links: [],
              manage_group_ids: [group.id]
            )
          )

          expect(Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid).map(&:user_id))
            .to contain_exactly(user3.id)
        end
      end

      context 'with empty target list' do
        it 'removes all members' do
          worker.perform(scim_group_uid, [], 'replace')

          expect(Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid)).to be_empty

          group.reload
          expect(group.users.include?(user1)).to be_falsey
          expect(group.users.include?(user2)).to be_falsey
        end
      end

      context 'with multiple users having different SCIM group memberships' do
        let_it_be(:user4) { create(:user) }
        let_it_be(:user5) { create(:user) }
        let_it_be(:scim_group_uid_2) { SecureRandom.uuid }
        let_it_be(:scim_group_uid_3) { SecureRandom.uuid }

        before do
          create(:scim_group_membership, user: user1, scim_group_uid: scim_group_uid_2)
          create(:scim_group_membership, user: user4, scim_group_uid: scim_group_uid)
          create(:scim_group_membership, user: user4, scim_group_uid: scim_group_uid_3)
          create(:scim_group_membership, user: user5, scim_group_uid: scim_group_uid)

          group.add_member(user4, Gitlab::Access::DEVELOPER)
          group.add_member(user5, Gitlab::Access::DEVELOPER)

          create(:saml_group_link, group: group, scim_group_uid: scim_group_uid_2)
          create(:saml_group_link, group: group, scim_group_uid: scim_group_uid_3)

          sync_service_double = instance_double(Groups::SyncService)
          allow(Groups::SyncService).to receive(:new).and_return(sync_service_double)
          allow(sync_service_double).to receive(:execute)
        end

        it 'handles multiple users with batched queries' do
          worker.perform(scim_group_uid, [user3.id], 'replace')

          expect(Groups::SyncService).to have_received(:new).with(
            group,
            user4,
            hash_including(
              group_links: array_including(
                have_attributes(scim_group_uid: scim_group_uid_3)
              ),
              manage_group_ids: [group.id]
            )
          )

          expect(Groups::SyncService).to have_received(:new).with(
            group,
            user5,
            hash_including(
              group_links: [],
              manage_group_ids: [group.id]
            )
          )

          expect(Authn::ScimGroupMembership.by_scim_group_uid(scim_group_uid).map(&:user_id))
            .to contain_exactly(user3.id)
        end
      end
    end

    context 'with empty arrays' do
      it 'handles empty user IDs' do
        expect { worker.perform(scim_group_uid, [], 'add') }
          .not_to change { [group.members.count, another_group.members.count] }
      end
    end

    context 'with invalid operation type' do
      it 'does nothing for unknown operation types' do
        expect { worker.perform(scim_group_uid, user_ids, 'invalid_op') }
          .not_to change { [group.members.count, another_group.members.count] }
      end

      it 'does nothing for nil operation type' do
        expect { worker.perform(scim_group_uid, user_ids, nil) }
          .not_to change { [group.members.count, another_group.members.count] }
      end

      it 'logs a warning for unsupported operation types' do
        expect(Gitlab::AppLogger).to receive(:warn).with(
          message: 'Unsupported SCIM group membership operation',
          operation_type: 'invalid_op',
          scim_group_uid: scim_group_uid
        )

        worker.perform(scim_group_uid, user_ids, 'invalid_op')
      end
    end
  end
end
