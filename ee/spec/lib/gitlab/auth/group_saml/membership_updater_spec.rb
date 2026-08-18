# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::MembershipUpdater, feature_category: :system_access do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:member_role) { create(:member_role, :developer, namespace: group) }
  let_it_be(:saml_provider) { create(:saml_provider, group: group, default_membership_role: Gitlab::Access::DEVELOPER, member_role: member_role) }

  subject(:update_membership) { described_class.new(user, saml_provider, auth_hash).execute }

  shared_examples 'not enqueueing Microsoft Group Sync worker' do
    it 'does not enqueue Microsoft Group Sync worker' do
      expect(::SystemAccess::GroupSamlMicrosoftGroupSyncWorker).not_to receive(:perform_async)

      update_membership
    end
  end

  shared_examples 'not enqueueing Group SAML Group Sync worker' do
    it 'does not enqueue Microsoft Group Sync worker' do
      expect(GroupSamlGroupSyncWorker).not_to receive(:perform_async)

      update_membership
    end
  end

  context 'for default behavior' do
    let_it_be(:auth_hash) { {} }

    it 'adds the user to the group' do
      update_membership

      expect(group).to have_user(user)
    end

    it 'adds the member with the specified `default_membership_role`' do
      expect(group).to receive(:add_member).with(user, Gitlab::Access::DEVELOPER, member_role_id: member_role.id).and_call_original

      update_membership

      created_member = group.members.find_by(user: user)
      expect(created_member.access_level).to eq(Gitlab::Access::DEVELOPER)
    end

    it 'adds the member with the specified `member_role`', feature_category: :permissions do
      stub_licensed_features(custom_roles: true)

      update_membership

      expect(group.member(user).member_role).to eq(member_role)
    end

    it "doesn't duplicate group membership" do
      group.add_guest(user)

      update_membership

      expect(group.members.count).to eq 1
    end

    it "doesn't overwrite existing membership level" do
      group.add_maintainer(user)

      update_membership

      expect(group.members.pluck(:access_level)).to eq([Gitlab::Access::MAINTAINER])
    end

    context 'when audit events triggered' do
      let!(:expected_audit_context) do
        {
          name: 'group_saml_member_added',
          author: user,
          scope: group,
          target: user,
          message: 'Added as SAML group member',
          additional_details: {
            add: 'user_access',
            as: 'Developer',
            custom_message: "User #{user.name} added to group #{group.name} through SAML authentication"
          }
        }
      end

      it 'sends the audit streaming event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_audit_context)

        update_membership
      end

      it 'does not send audit event when member is not persisted' do
        allow(group).to receive(:add_member).and_return(nil)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        update_membership
      end

      it 'does not send audit event when user is already a member' do
        group.add_guest(user)

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        update_membership
      end

      context "for allowed_email_domain restrictions" do
        before do
          stub_licensed_features(group_allowed_email_domains: true)
        end

        it "does not log an audit event when domain restrictions are in place" do
          create :allowed_email_domain, group: group, domain: 'somethingveryrandom.com'

          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          update_membership
        end

        it "logs an audit event if the member's email is accepted" do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(expected_audit_context)

          update_membership
        end
      end
    end

    it_behaves_like 'not enqueueing Group SAML Group Sync worker'
    it_behaves_like 'not enqueueing Microsoft Group Sync worker'
  end

  context 'with BSO (Block Seat Overages) enabled', :saas do
    let_it_be(:auth_hash) { {} }

    before do
      stub_feature_flags(bso_minimal_access_fallback: true)
      stub_licensed_features(minimal_access_role: true)
    end

    context 'without available seats' do
      before do
        group.namespace_settings.update!(seat_control: :block_overages)

        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:seats_available_for?).and_return(false)
      end

      it 'adds user with MINIMAL_ACCESS instead of the desired access level' do
        expect { update_membership }.to change { group.all_group_members.count }.by(1)

        member = group.all_group_members.find_by(user: user)
        expect(member).not_to be_nil
        expect(member.access_level).to eq(Gitlab::Access::MINIMAL_ACCESS)
      end

      it 'logs BSO adjustment when access level is downgraded' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          hash_including(
            message: 'Group membership access level adjusted due to BSO seat limits',
            group_id: group.id,
            group_path: group.full_path,
            user_id: user.id,
            requested_access_level: Gitlab::Access::DEVELOPER,
            adjusted_access_level: Gitlab::Access::MINIMAL_ACCESS,
            feature_flag: 'bso_minimal_access_fallback'
          )
        )

        update_membership
      end

      it 'tracks minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
        update_membership

        ::Gitlab::Redis::SharedState.with do |redis|
          current_date = Date.current.iso8601
          users_key = "seat_aware_provisioning:group:#{group.id}:{#{current_date}}"
          root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

          expect(redis.sismember(users_key, user.id.to_s)).to be true
          expect(redis.sismember(root_groups_key, group.root_ancestor.id.to_s)).to be true
        end
      end

      it 'audits minimal access role adjustment' do
        update_membership

        audit_event = AuditEventReader.find_by(target_id: user.id)

        expect(audit_event.entity).to eq(group)
        expect(audit_event.details[:user_id]).to eq(user.id)
        expect(audit_event.details[:requested_access_level]).to eq(Gitlab::Access::DEVELOPER)
        expect(audit_event.details[:saml_provider_id]).to eq(group.saml_provider.id)
      end
    end

    context 'with available seats' do
      before do
        group.namespace_settings.update!(seat_control: :block_overages)

        allow(GitlabSubscriptions::MemberManagement::BlockSeatOverages)
          .to receive(:seats_available_for?).and_return(true)
      end

      it 'adds user with the original desired access level' do
        expect { update_membership }.to change { group.members.count }.by(1)

        member = group.member(user)
        expect(member).not_to be_nil
        expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
      end

      it 'does not log BSO adjustment' do
        expect(Gitlab::AppLogger).not_to receive(:info).with(
          hash_including(message: 'Group membership access level adjusted due to BSO seat limits')
        )

        update_membership
      end

      it 'does not track minimal access provisioning', :clean_gitlab_redis_shared_state, :freeze_time do
        update_membership

        ::Gitlab::Redis::SharedState.with do |redis|
          current_date = Date.current.iso8601
          users_key = "seat_aware_provisioning:group:#{group.id}:{#{current_date}}"
          root_groups_key = "seat_aware_provisioning:group:{#{current_date}}"

          expect(redis.sismember(users_key, user.id.to_s)).to be false
          expect(redis.sismember(root_groups_key, group.root_ancestor.id.to_s)).to be false
        end
      end
    end
  end

  context 'when SAML group links exist' do
    let!(:group_link) { create(:saml_group_link, saml_group_name: 'Owners', group: group) }
    let!(:subgroup_link) { create(:saml_group_link, saml_group_name: 'Developers', group: create(:group, parent: group)) }

    context 'when the auth hash contains groups' do
      let_it_be(:auth_hash) do
        Gitlab::Auth::GroupSaml::AuthHash.new(
          OmniAuth::AuthHash.new(extra: {
            raw_info: OneLogin::RubySaml::Attributes.new('groups' => %w[Developers Owners])
          })
        )
      end

      context 'when group sync is not available' do
        before do
          stub_saml_group_sync_available(false)
        end

        it_behaves_like 'not enqueueing Group SAML Group Sync worker'
      end

      context 'when group sync is available' do
        before do
          stub_saml_group_sync_available(true)
        end

        it 'enqueues group sync' do
          expect(GroupSamlGroupSyncWorker)
            .to receive(:perform_async).with(user.id, group.id, match_array([group_link.id, subgroup_link.id]))

          update_membership
        end

        context 'with a group link outside the top-level group' do
          before do
            create(:saml_group_link, saml_group_name: 'Developers', group: create(:group))
          end

          it 'enqueues group sync without the outside group' do
            expect(GroupSamlGroupSyncWorker)
              .to receive(:perform_async).with(user.id, group.id, match_array([group_link.id, subgroup_link.id]))

            update_membership
          end
        end

        context 'when auth hash contains no groups' do
          let!(:auth_hash) do
            Gitlab::Auth::GroupSaml::AuthHash.new(
              OmniAuth::AuthHash.new(extra: { raw_info: OneLogin::RubySaml::Attributes.new })
            )
          end

          it 'enqueues group sync' do
            expect(GroupSamlGroupSyncWorker).to receive(:perform_async).with(user.id, group.id, [])

            update_membership
          end
        end

        context 'when auth hash groups do not match group links' do
          before do
            group_link.update!(saml_group_name: 'Web Developers')
            subgroup_link.destroy!
          end

          it 'enqueues group sync' do
            expect(GroupSamlGroupSyncWorker).to receive(:perform_async).with(user.id, group.id, [])

            update_membership
          end
        end
      end
    end

    context 'when the auth hash contains a Microsoft group claim' do
      let_it_be(:auth_hash) do
        Gitlab::Auth::GroupSaml::AuthHash.new(
          OmniAuth::AuthHash.new(extra: {
            raw_info: OneLogin::RubySaml::Attributes.new({
              'http://schemas.microsoft.com/claims/groups.link' =>
                ['https://graph.windows.net/8c750e43/users/e631c82c/getMemberObjects']
            })
          })
        )
      end

      context 'when Microsoft Group Sync is not licensed' do
        let!(:application) { create(:system_access_microsoft_application, enabled: true, namespace: group) }

        before do
          stub_saml_group_sync_available(true)
        end

        it_behaves_like 'not enqueueing Microsoft Group Sync worker'
      end

      context 'when Microsoft Group Sync is licensed' do
        before do
          stub_licensed_features(microsoft_group_sync: true)
        end

        it_behaves_like 'not enqueueing Microsoft Group Sync worker'

        context 'when SAML Group Sync is not available' do
          before do
            stub_saml_group_sync_available(false)
          end

          it_behaves_like 'not enqueueing Microsoft Group Sync worker'

          context 'when a Microsoft Application is present and enabled' do
            let!(:application) { create(:system_access_microsoft_application, enabled: true, namespace: group) }

            it_behaves_like 'not enqueueing Microsoft Group Sync worker'
          end
        end

        context 'when Group SAML Group Sync is enabled' do
          before do
            stub_saml_group_sync_available(true)
          end

          it_behaves_like 'not enqueueing Microsoft Group Sync worker'

          context 'when a group Microsoft Application is present' do
            let!(:application) { create(:system_access_group_microsoft_application, group: group) }

            context 'when the Microsoft Application is not enabled' do
              before do
                application.update!(enabled: false)
              end

              it_behaves_like 'not enqueueing Microsoft Group Sync worker'
            end

            context 'when the Microsoft application is enabled' do
              before do
                application.update!(enabled: true)
              end

              it 'enqueues Microsoft Group Sync worker' do
                expect(::SystemAccess::GroupSamlMicrosoftGroupSyncWorker)
                  .to receive(:perform_async).with(user.id, group.id)

                update_membership
              end

              it_behaves_like 'not enqueueing Group SAML Group Sync worker'
            end
          end
        end
      end
    end

    # Microsoft should never send both, but it's important we're only running
    # one sync. This test serves to ensure we have that safeguard in place.
    context 'when the auth hash contains both groups and a group claim' do
      let_it_be(:auth_hash) do
        Gitlab::Auth::GroupSaml::AuthHash.new(
          OmniAuth::AuthHash.new(extra: {
            raw_info: OneLogin::RubySaml::Attributes.new({
              'groups' => %w[Developers Owners],
              'http://schemas.microsoft.com/claims/groups.link' =>
                ['https://graph.windows.net/8c750e43/users/e631c82c/getMemberObjects']
            })
          })
        )
      end

      let_it_be(:application) { create(:system_access_group_microsoft_application, enabled: true, group: group) }

      before do
        stub_licensed_features(microsoft_group_sync: true)
        stub_saml_group_sync_available(true)
      end

      it 'enqueues Microsoft Group Sync worker' do
        expect(::SystemAccess::GroupSamlMicrosoftGroupSyncWorker)
          .to receive(:perform_async).with(user.id, group.id)

        update_membership
      end

      it_behaves_like 'not enqueueing Group SAML Group Sync worker'
    end
  end

  def stub_saml_group_sync_available(enabled)
    allow(group).to receive(:saml_group_sync_available?).and_return(enabled)
  end
end
