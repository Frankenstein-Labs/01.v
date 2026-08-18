# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GroupLinks::UpdateService, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create :group }
  let_it_be(:project) { create(:project, owners: user) }

  let!(:link) { create(:project_group_link, project: project, group: group, group_access: Gitlab::Access::DEVELOPER) }

  let(:expiry_date) { 1.month.from_now.to_date }
  let(:group_link_params) do
    { group_access: Gitlab::Access::GUEST,
      expires_at: expiry_date }
  end

  subject(:execute_update_service) { described_class.new(link, user).execute(group_link_params) }

  context 'audit events' do
    it 'sends the audit streaming event' do
      audit_context = {
        name: 'project_group_link_updated',
        author: user,
        scope: project,
        target: group,
        message: "Changed project group link profile group_access from Developer to Guest \
profile expires_at from nil to #{expiry_date}",
        additional_details: {
          change: {
            access_level: { from: 'Developer', to: 'Guest' },
            invite_expiry: { from: 'nil', to: expiry_date }
          }
        }
      }
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

      execute_update_service
    end

    context 'when only expires_at is updated' do
      let(:group_link_params) do
        { expires_at: expiry_date }
      end

      it 'sends the audit streaming event' do
        audit_context = {
          name: 'project_group_link_updated',
          author: user,
          scope: project,
          target: group,
          message: "Changed project group link profile expires_at from nil to #{expiry_date}",
          additional_details: {
            change: {
              invite_expiry: { from: 'nil', to: expiry_date }
            }
          }
        }
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

        execute_update_service
      end

      context 'when expires_at is already same' do
        let(:group_link_params) do
          { expires_at: expiry_date }
        end

        before do
          link.update!(expires_at: expiry_date)
        end

        it 'does not send audit streaming event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute_update_service
        end
      end
    end

    context 'when only access_level is updated' do
      let(:group_link_params) do
        { group_access: Gitlab::Access::GUEST }
      end

      it 'sends the audit streaming event' do
        audit_context = {
          name: 'project_group_link_updated',
          author: user,
          scope: project,
          target: group,
          message: "Changed project group link profile group_access from Developer to Guest",
          additional_details: {
            change: {
              access_level: { from: 'Developer', to: 'Guest' }
            }
          }
        }
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

        execute_update_service
      end

      context 'when access_level is already same' do
        let(:group_link_params) do
          { group_access: Gitlab::Access::GUEST }
        end

        before do
          link.update!(group_access: Gitlab::Access::GUEST)
        end

        it 'does not send audit streaming event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          execute_update_service
        end
      end
    end
  end

  context 'with member_role_id param', :saas do
    let_it_be(:current_member_role) { create(:member_role, namespace: project.root_ancestor) }
    let_it_be(:new_member_role) { create(:member_role, namespace: project.root_ancestor) }

    let_it_be_with_reload(:link) do
      create(:project_group_link, project: project, group: group, group_access: current_member_role.base_access_level,
        member_role: current_member_role)
    end

    let(:group_link_params) do
      super().merge({ group_access: current_member_role.base_access_level, member_role_id: new_member_role.id })
    end

    before do
      stub_licensed_features(custom_roles: true)
    end

    shared_examples_for 'does update the link\'s member role' do
      specify do
        expect { execute_update_service }.not_to change { link.reload.member_role_id }
      end
    end

    it 'updates the link\'s member role' do
      expect { execute_update_service }.to change {
        link.reload.member_role_id
      }.from(current_member_role.id).to(new_member_role.id)
    end

    describe "Authz::UserProjectMemberRole records of the invited group's members" do
      shared_examples 'enqueues UpdateForSharedProjectWorker job' do
        it 'enqueues an ::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker job' do
          expect(::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker)
            .to receive(:perform_async).with(link.id)

          execute_update_service
        end
      end

      shared_examples 'does not enqueue an ::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker job' do
        it 'does not enqueue an ::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker job' do
          expect(::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker).not_to receive(:perform_async)

          execute_update_service
        end
      end

      it_behaves_like 'enqueues UpdateForSharedProjectWorker job'

      context 'when only access level was updated' do
        let(:group_link_params) { { group_access: Gitlab::Access::GUEST } }

        before do
          link.update!(member_role: nil)
        end

        it_behaves_like 'enqueues UpdateForSharedProjectWorker job'
      end

      context 'when neither member role nor access level was updated' do
        let(:group_link_params) { { expires_at: expiry_date } }

        it_behaves_like 'does not enqueue an ::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker job'
      end

      context 'when cache_user_project_member_roles feature flag is disabled' do
        before do
          stub_feature_flags(cache_user_project_member_roles: false)
        end

        it_behaves_like 'does not enqueue an ::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker job'
      end
    end

    context 'when assign_custom_roles_to_project_links_saas feature flag is disabled' do
      before do
        stub_feature_flags(assign_custom_roles_to_project_links_saas: false)
      end

      it_behaves_like 'does update the link\'s member role'
    end

    context 'when custom roles feature is not available' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it_behaves_like 'does update the link\'s member role'
    end
  end
end
