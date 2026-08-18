# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::GroupLinks::CreateService, '#execute', feature_category: :groups_and_projects do
  let_it_be(:shared_with_group) { create(:group, :private) }
  let_it_be_with_refind(:group) { create(:group, :private) }

  let_it_be(:user) { create(:user) }

  let(:role) { Gitlab::Access::DEVELOPER }
  let(:opts) { { shared_group_access: role, expires_at: nil } }

  let(:service) { described_class.new(group, shared_with_group, user, opts) }

  subject(:create_service) { service.execute }

  before do
    shared_with_group.add_guest(user)
    group.add_owner(user)
  end

  describe 'audit event creation' do
    let(:audit_context) do
      {
        name: 'group_share_with_group_link_created',
        stream_only: false,
        author: user,
        scope: group,
        target: shared_with_group,
        message: "Invited #{shared_with_group.name} to the group #{group.name}"
      }
    end

    it 'sends an audit event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context).once

      create_service
    end
  end

  context 'for custom roles' do
    context 'when current user has admin_group_member custom permission' do
      let_it_be(:role) { create(:member_role, :maintainer, namespace: group, admin_group_member: true) }
      let_it_be(:member) do
        create(:group_member, :maintainer, member_role: role, user: user, group: group)
      end

      before do
        stub_licensed_features(custom_roles: true)
      end

      it 'the user cannot create the group link' do
        expect { create_service }.not_to change { group.shared_with_group_links.count }
      end
    end

    context 'when assigning a member role to group link' do
      let_it_be(:member_role) { create(:member_role, namespace: group) }

      let(:opts) { { shared_group_access: Gitlab::Access::DEVELOPER, member_role_id: member_role.id } }

      context 'when custom_roles feature is enabled' do
        before do
          stub_licensed_features(custom_roles: true)
        end

        it 'assigns member role to group link' do
          expect(create_service[:link][:member_role_id]).to eq(member_role.id)
        end

        context 'when the member role is in a different namespace' do
          let_it_be(:member_role) { create(:member_role, namespace: create(:group)) }

          it 'returns error' do
            expect(create_service[:status]).to eq(:error)
            expect(create_service[:message]).to eq("Group must be in same hierarchy as custom role's namespace")
          end
        end

        context 'when the member role is created on the instance-level' do
          let_it_be(:member_role) { create(:member_role, :instance) }

          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it 'assigns member role to group link' do
            expect(create_service[:link][:member_role_id]).to eq(member_role.id)
          end
        end

        describe "Authz::UserGroupMemberRole records of the shared_with_group's members" do
          it 'enqueues a ::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker job' do
            allow(::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker).to receive(:perform_async)

            link_id = create_service[:link][:id]

            expect(::Authz::UserGroupMemberRoles::UpdateForSharedGroupWorker)
              .to have_received(:perform_async).with(link_id)
          end
        end
      end

      context 'when custom_roles feature is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it 'does not assign member role to group link' do
          expect(create_service[:link][:member_role_id]).to be_nil
        end
      end
    end
  end

  context 'with the licensed feature for disable_invite_members' do
    shared_examples 'successful group link creation' do
      it 'creates a group link' do
        expect { create_service }.to change { group.shared_with_group_links.count }.by(1)
      end
    end

    shared_examples 'failed group link creation' do
      it 'does not create a group link' do
        expect { create_service }.not_to change { group.shared_with_group_links.count }
      end
    end

    context 'when the user is a group owner' do
      before_all do
        shared_with_group.add_guest(user)
        group.add_owner(user)
      end

      context 'and the licensed feature is available' do
        before do
          stub_licensed_features(disable_invite_members: true)
        end

        context 'and the setting disable_invite_members is ON' do
          before do
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like 'failed group link creation'
        end

        context 'and the setting disable_invite_members is OFF' do
          before do
            stub_application_setting(disable_invite_members: false)
          end

          it_behaves_like 'successful group link creation'
        end
      end

      context 'and the licensed feature is unavailable' do
        before do
          stub_licensed_features(disable_invite_members: false)
          stub_application_setting(disable_invite_members: true)
        end

        it_behaves_like 'successful group link creation'
      end
    end

    context 'when the user is an admin and the setting disable_invite_members is ON' do
      let_it_be(:user) { create(:admin) }

      before do
        stub_licensed_features(disable_invite_members: true)
        stub_application_setting(disable_invite_members: true)
      end

      context 'with admin mode enabled', :enable_admin_mode do
        it_behaves_like 'successful group link creation'
      end

      it_behaves_like 'failed group link creation'
    end
  end
end
