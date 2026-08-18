# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupSamlGroupSyncWorker, feature_category: :user_management do
  include ::SystemAccess::GroupSyncHelpers

  describe '#perform' do
    let_it_be(:user) { create(:user) }

    let_it_be_with_reload(:top_level_group) { create(:group) }
    let_it_be(:top_level_group_link) do
      create(:saml_group_link, group: top_level_group, access_level: Gitlab::Access::DEVELOPER)
    end

    let_it_be(:group) { create(:group, parent: top_level_group) }
    let_it_be(:group_link) do
      create(:saml_group_link, group: group, access_level: Gitlab::Access::DEVELOPER)
    end

    let(:worker) { described_class.new }

    context 'when the group does not have group_saml_group_sync feature licensed' do
      before do
        create(:saml_provider, group: top_level_group, enabled: true)
      end

      it 'does not call the sync service' do
        expect(Groups::SyncService).not_to receive(:new)

        perform([top_level_group_link.id])
      end
    end

    context 'when the group has group_saml_group_sync feature licensed' do
      before do
        stub_licensed_features(saml_group_sync: true)
      end

      context 'when SAML is not enabled' do
        it 'does not call the sync service' do
          expect(Groups::SyncService).not_to receive(:new)

          perform([top_level_group_link.id])
        end
      end

      context 'when SAML is enabled' do
        let_it_be_with_reload(:saml_provider) do
          create(:saml_provider, group: top_level_group, enabled: true, default_membership_role: Gitlab::Access::GUEST)
        end

        let(:top_level_member) { top_level_group.member(user) }

        subject(:top_level_member_access_level) { top_level_member.access_level }

        context 'default membership' do
          context 'when group link ids do not include the top level group' do
            it 'does not pass the top level group to the sync service as group to manage' do
              top_level_group.add_member(user, saml_provider.default_membership_role)

              expect_sync_service_call(group_links: [group_link], manage_group_ids: [group.id])

              perform([group_link.id])
            end

            it 'retains user default membership role' do
              perform([group_link.id])

              expect(top_level_member_access_level)
                .to eq(top_level_group.saml_provider.default_membership_role)
            end

            context 'when the top-level default membership role is a custom role' do
              let(:member_role) do
                create(:member_role, namespace: top_level_group, base_access_level: Gitlab::Access::GUEST)
              end

              before do
                stub_licensed_features(saml_group_sync: true, custom_roles: true)
                saml_provider.update!(member_role: member_role)
              end

              it 'retains the default custom role' do
                perform([group_link.id])

                expect(top_level_member.member_role)
                  .to eq(top_level_group.saml_provider.member_role)
              end
            end

            context 'when the member is the last owner' do
              before do
                top_level_group.add_member(user, Gitlab::Access::OWNER)
              end

              it 'does not update the member when the member is the last owner' do
                expect_metadata_logging_call({ added: 0, updated: 0, removed: 0 })

                perform([group_link.id])

                expect(top_level_member_access_level)
                  .to eq(Gitlab::Access::OWNER)
              end
            end

            context 'when the membership role deviates from the default' do
              before do
                top_level_group.add_member(user, Gitlab::Access::MAINTAINER)
              end

              it 'reverts to the default membership role' do
                expect_metadata_logging_call({ added: 0, updated: 1, removed: 0 })

                perform([group_link.id])

                expect(top_level_member_access_level)
                  .to eq(top_level_group.saml_provider.default_membership_role)
              end

              it 'does not update the default membership when the top level group has no group links' do
                top_level_group_link.destroy!

                expect_sync_service_call(group_links: [group_link], manage_group_ids: [group.id])
                expect_metadata_logging_call({ added: 0, updated: 0, removed: 0 })

                perform([group_link.id])

                expect(top_level_member_access_level).to eq(Gitlab::Access::MAINTAINER)
              end
            end

            it 'does not update the membership role when it does not deviate from the default' do
              top_level_group.add_member(user, top_level_group.saml_provider.default_membership_role)

              expect_metadata_logging_call({ added: 1, updated: 0, removed: 0 })
              expect(top_level_group).not_to receive(:add_user)

              perform([group_link.id])

              expect(top_level_member_access_level)
                .to eq(top_level_group.saml_provider.default_membership_role)
            end
          end

          context 'when group link ids include the top level group' do
            it 'does not revert to the default membership role' do
              perform([top_level_group_link.id])

              expect(top_level_member_access_level).to eq(Gitlab::Access::DEVELOPER)
            end
          end
        end

        it 'calls the sync service with the group links' do
          expect_sync_service_call(group_links: [top_level_group_link, group_link])
          expect_metadata_logging_call({ added: 2, updated: 0, removed: 0 })

          perform([top_level_group_link.id, group_link.id])
        end

        it 'does not call the sync service when the user does not exist' do
          expect(Groups::SyncService).not_to receive(:new)

          described_class.new.perform(non_existing_record_id, top_level_group.id, [group_link])
        end

        it 'includes groups with links in manage_group_ids' do
          expect_sync_service_call(
            group_links: [top_level_group_link],
            manage_group_ids: [top_level_group.id, group.id]
          )

          perform([top_level_group_link.id])
        end

        context 'when a group link falls outside the top-level group' do
          let(:outside_group_link) { create(:saml_group_link, group: create(:group)) }

          it 'drops group links outside the top level group' do
            expect_sync_service_call(group_links: [top_level_group_link, group_link])
            expect_metadata_logging_call({ added: 2, updated: 0, removed: 0 })

            perform([outside_group_link.id, top_level_group_link.id, group_link.id])
          end
        end

        context 'with a group in the hierarchy that has no group links' do
          let(:group_without_links) { create(:group, parent: group) }

          it 'is not included in manage_group_ids' do
            expect_sync_service_call(group_links: [top_level_group_link, group_link])
            expect_metadata_logging_call({ added: 2, updated: 0, removed: 0 })

            perform([top_level_group_link.id, group_link.id])
          end
        end

        context 'when the worker receives no group link ids' do
          before do
            group.add_member(user, Gitlab::Access::MAINTAINER)
          end

          it 'calls the sync service, updates default membership and removes existing users' do
            expect_sync_service_call(group_links: [], manage_group_ids: [group.id])
            expect_metadata_logging_call({ added: 0, updated: 1, removed: 1 })

            perform([])

            expect(top_level_member_access_level).to eq(Gitlab::Access::GUEST)
          end
        end

        context 'with BSO (Block Seat Overages) enabled for default membership' do
          before do
            stub_saas_features(gitlab_com_subscriptions: true)
            stub_feature_flags(bso_minimal_access_fallback: true)
            stub_licensed_features(group_saml: true, saml_group_sync: true, minimal_access_role: true)

            top_level_group.namespace_settings.update!(seat_control: :block_overages)
          end

          context 'without available seats' do
            before do
              allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
                .to receive(:seats_available_for?).and_return(false)
            end

            it 'adds user with MINIMAL_ACCESS for default membership when reverting' do
              top_level_group.add_member(user, Gitlab::Access::MAINTAINER)

              expect_metadata_logging_call({ added: 0, updated: 1, removed: 0 })

              perform([group_link.id])

              member = top_level_group.all_group_members.find_by(user: user)
              expect(member&.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
            end

            it 'logs BSO adjustment when access level is downgraded' do
              top_level_group.add_maintainer(user)

              allow(Gitlab::AppLogger).to receive(:info).and_call_original
              expect(Gitlab::AppLogger).to receive(:info).with(
                hash_including(
                  message: 'Group membership access level adjusted due to BSO seat limits',
                  group_id: top_level_group.id,
                  group_path: top_level_group.full_path,
                  user_id: user.id,
                  requested_access_level: Gitlab::Access::GUEST,
                  adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
                  feature_flag: 'bso_minimal_access_fallback'
                )
              )

              perform([group_link.id])
            end

            it 'tracks minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
              top_level_group.add_member(user, Gitlab::Access::MAINTAINER)

              perform([group_link.id])

              ::Gitlab::Redis::SharedState.with do |redis|
                current_date = Date.current.iso8601
                users_key = "seat_aware_provisioning:group:#{top_level_group.id}:{#{current_date}}"
                root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

                expect(redis.sismember(users_key, user.id.to_s)).to be true
                expect(redis.sismember(root_groups_key, top_level_group.root_ancestor.id.to_s)).to be true
              end
            end

            it 'audits minimal access role adjustment' do
              member = top_level_group.add_maintainer(user)

              perform([group_link.id])

              audit_event = AuditEventReader.find_by(target_id: user.id)

              expect(audit_event.entity).to eq(top_level_group)
              expect(audit_event.details[:member_id]).to eq(member.id)
              expect(audit_event.details[:user_id]).to eq(user.id)
              expect(audit_event.details[:requested_access_level]).to eq(Gitlab::Access::GUEST)
              expect(audit_event.details[:saml_provider_id]).to eq(top_level_group.saml_provider.id)
            end
          end

          context 'with available seats' do
            before do
              allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
                .to receive(:seats_available_for?).and_return(true)
            end

            it 'adds user with the original default membership role' do
              top_level_group.add_member(user, Gitlab::Access::MAINTAINER)

              expect_metadata_logging_call({ added: 0, updated: 1, removed: 0 })

              perform([group_link.id])

              member = top_level_group.all_group_members.find_by(user: user)
              expect(member&.access_level).to eq(Gitlab::Access::GUEST)
            end

            it 'does not track minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
              top_level_group.add_member(user, Gitlab::Access::MAINTAINER)

              perform([group_link.id])

              ::Gitlab::Redis::SharedState.with do |redis|
                current_date = Date.current.iso8601
                users_key = "seat_aware_provisioning:group:#{top_level_group.id}:{#{current_date}}"
                root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

                expect(redis.sismember(users_key, user.id.to_s)).to be false
                expect(redis.sismember(root_groups_key, top_level_group.root_ancestor.id.to_s)).to be false
              end
            end
          end
        end
      end
    end

    def perform(group_links)
      worker.perform(user.id, top_level_group.id, group_links)
    end
  end
end
