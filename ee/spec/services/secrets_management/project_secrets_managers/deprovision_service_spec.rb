# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecretsManagers::DeprovisionService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, owner_of: project) }
  let_it_be(:member_user) { create(:user) }
  let_it_be(:member_role) { create(:member_role, namespace: group) }

  let_it_be(:group_member) do
    create(:group_member, {
      user: member_user,
      group: member_role.namespace,
      access_level: Gitlab::Access::DEVELOPER,
      member_role: member_role
    })
  end

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:maintenance_task) do
    create(:project_secrets_manager_maintenance_task, :deprovision,
      project: project,
      user: user
    )
  end

  let(:service) { described_class.new(maintenance_task, user) }

  subject(:result) { service.execute }

  describe '#execute', :aggregate_failures do
    before do
      provision_project_secrets_manager(secrets_manager, user)

      create_project_secret(
        user: user,
        project: project,
        name: 'TEST_SECRET',
        branch: 'development',
        environment: 'dev-*',
        value: 'test'
      )

      update_project_secrets_permission(
        user: user,
        project: project,
        actions: %w[read],
        principal: { id: member_role.id, type: 'MemberRole' }
      )
    end

    let(:payload_key) { :project_secrets_manager_maintenance_task }
    let(:find_sm_target) { SecretsManagement::ProjectSecretsManager }
    let(:parent_fk_column) { :project_id }

    def expect_no_policies_at(full_path)
      expect_project_to_have_no_policies(full_path)
    end

    it_behaves_like 'a secrets manager deprovision service'
    it_behaves_like 'an operation requiring an exclusive project secret operation lease', 120.seconds

    it 'enqueues a namespace secret count refresh after destroying the manager' do
      expect(SecretsManagement::ReconcileNamespaceSecretCountWorker)
        .to receive(:perform_async)
        .with(secrets_manager.namespace_id_for_secret_count, user.id)

      expect(result).to be_success
    end

    context 'when multiple projects share the same root namespace' do
      let!(:another_project) { create(:project, group: group) }
      let(:another_secrets_manager) { create(:project_secrets_manager, project: another_project) }

      before do
        provision_project_secrets_manager(another_secrets_manager, user)
      end

      it 'only deletes this project resources without affecting other projects' do
        expect_jwt_cel_role_to_exist(
          another_secrets_manager.full_namespace_path,
          another_secrets_manager.ci_auth_mount,
          another_secrets_manager.ci_auth_role
        )

        expect(result).to be_success

        # This project's resources are gone
        expect_kv_secret_engine_not_to_be_mounted(secrets_manager.full_namespace_path,
          secrets_manager.ci_secrets_mount_path)
        expect_project_to_have_no_policies(secrets_manager.full_namespace_path)
        expect(SecretsManagement::ProjectSecretsManager.find_by(id: secrets_manager.id)).to be_nil

        # Sibling project's resources still exist
        expect_jwt_cel_role_to_exist(
          another_secrets_manager.full_namespace_path,
          another_secrets_manager.ci_auth_mount,
          another_secrets_manager.ci_auth_role
        )
        expect_kv_secret_engine_to_be_mounted(another_secrets_manager.full_namespace_path,
          another_secrets_manager.ci_secrets_mount_path)
        expect(another_secrets_manager.reload).to be_present
      end
    end
  end
end
