# frozen_string_literal: true

require 'spec_helper'
RSpec.describe SecretsManagement::ProjectSecrets::DeleteService, :gitlab_secrets_manager, feature_category: :secrets_management do
  include SecretsManagement::GitlabSecretsManagerHelpers

  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user, owner_of: project) }

  let(:service) { described_class.new(project, user) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:value) { 'the-secret-value' }
  let(:branch) { 'main' }
  let(:environment) { 'prod' }

  describe '#execute', :aggregate_failures do
    context 'when the project secrets manager is active' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }

      subject(:result) { service.execute(name) }

      before do
        provision_project_secrets_manager(secrets_manager, user)

        # Create a secret to delete
        create_project_secret(
          user: user,
          project: project,
          name: name,
          value: value,
          branch: branch,
          environment: environment,
          description: description
        )
      end

      context 'when the secret exists' do
        it 'deletes a project secret and cleans up everything' do
          expect(result).to be_success
          expect(result.payload[:secret]).to be_present
          expect(result.payload[:secret].name).to eq(name)
          expect(result.payload[:secret].description).to eq(description)
          expect(result.payload[:secret].branch).to eq(branch)
          expect(result.payload[:secret].environment).to eq(environment)

          expect_kv_secret_not_to_exist(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name)
          )

          # Since this was the only secret, the policy should be completely deleted
          policy_name = project.secrets_manager.ci_policy_name(environment, branch)
          expect_policy_not_to_exist(
            project.secrets_manager.full_project_namespace_path,
            policy_name
          )

          expect_project_secret_not_to_exist(project, name, user)
        end

        it_behaves_like 'an operation requiring an exclusive project secret operation lease'
      end

      context 'when multiple secrets share the same policy' do
        let(:second_secret_name) { 'SECOND_SECRET' }
        let(:second_secret_environment) { environment }
        let(:second_secret_branch) { branch }

        before do
          # Create a second secret with the same environment and branch
          # This will share the same policy as the first secret
          create_project_secret(
            user: user,
            project: project,
            name: second_secret_name,
            value: "second-value",
            branch: second_secret_branch,
            environment: second_secret_environment,
            description: "Second secret"
          )
        end

        it 'deletes the secret but preserves the policy with remaining secret paths' do
          expect(result).to be_success

          expect_kv_secret_not_to_exist(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name)
          )

          policy_name = project.secrets_manager.ci_policy_name(environment, branch)

          client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
          updated_policy = client.get_policy(policy_name)
          expect(updated_policy).to be_present

          # First secret paths should be removed from the policy
          first_path = project.secrets_manager.ci_full_path(name)
          expect(updated_policy.paths.keys).not_to include(first_path)

          # Second secret should still have its paths and capabilities
          second_path = project.secrets_manager.ci_full_path(second_secret_name)
          expect(updated_policy.paths[second_path].capabilities).to include("read")

          expect_project_secret_not_to_exist(project, name, user)
        end

        context 'with wildcard patterns' do
          let(:wildcard_branch) { 'feature/*' }
          let(:wildcard_environment) { 'staging-*' }
          let(:environment) { wildcard_environment }
          let(:branch) { wildcard_branch }

          context 'when no other secrets share the same wildcard patterns' do
            let(:second_secret_branch) { 'dev/*' }
            let(:second_secret_environment) { 'prod-*' }

            it 'deletes the secret and its wildcard policy' do
              wildcard_result = described_class.new(project, user).execute(name)
              expect(wildcard_result).to be_success

              expect_kv_secret_not_to_exist(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name)
              )

              policy_name = project.secrets_manager.ci_policy_name(wildcard_environment, wildcard_branch)
              expect_policy_not_to_exist(project.secrets_manager.full_project_namespace_path, policy_name)
            end
          end

          context 'when other secrets share the same wildcard patterns' do
            let(:second_secret_branch) { wildcard_branch }
            let(:second_secret_environment) { wildcard_environment }

            it 'preserves the shared wildcard policy and the other secret' do
              first_delete_result = described_class.new(project, user).execute(name)
              expect(first_delete_result).to be_success

              expect_kv_secret_not_to_exist(
                project.secrets_manager.full_project_namespace_path,
                project.secrets_manager.ci_secrets_mount_path,
                secrets_manager.ci_data_path(name)
              )

              client = secrets_manager_client.with_namespace(secrets_manager.full_project_namespace_path)
              shared_policy_name = project.secrets_manager.ci_policy_name(wildcard_environment, wildcard_branch)
              shared_policy = client.get_policy(shared_policy_name)
              expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(second_secret_name))

              read_service = SecretsManagement::ProjectSecrets::ReadMetadataService.new(project, user)
              read_result = read_service.execute(second_secret_name)
              expect(read_result).to be_success
              expect(read_result.payload[:secret].name).to eq(second_secret_name)

              second_delete_result = described_class.new(project, user).execute(second_secret_name)
              expect(second_delete_result).to be_success

              expect_policy_not_to_exist(project.secrets_manager.full_project_namespace_path, shared_policy_name)
            end
          end
        end
      end

      context 'when the secret does not exist' do
        let(:nonexistent_name) { 'NONEXISTENT_SECRET' }

        subject(:nonexistent_result) { service.execute(nonexistent_name) }

        it 'returns an error' do
          expect(nonexistent_result).not_to be_success
          expect(nonexistent_result.message).to eq('Project secret does not exist.')
        end
      end
    end

    context 'when user is a developer and no permissions' do
      let_it_be_with_reload(:secrets_manager) { create(:project_secrets_manager, project: project) }
      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute(name) }

      it 'returns an error' do
        provision_project_secrets_manager(secrets_manager, user)
        expect { result }
        .to raise_error(SecretsManagement::SecretsManagerClient::ApiError,
          "1 error occurred:\n\t* permission denied\n\n")
      end
    end

    context "when project's group has proper permissions" do
      let(:group) { create(:group) }
      let(:project) { create(:project, group: group) }
      let(:secrets_manager) { create(:project_secrets_manager, project: project) }

      let(:user) { create(:user, developer_of: project) }

      subject(:result) { service.execute(name) }

      before do
        provision_project_secrets_manager(secrets_manager, user)
        update_project_secrets_permission(
          user: user, project: project, actions: %w[
            write delete read
          ], principal: { id: group.id, type: 'Group' }
        )

        # Create a secret to delete
        create_project_secret(
          user: user,
          project: project,
          name: name,
          value: value,
          branch: branch,
          environment: environment,
          description: description
        )
      end

      it 'returns success' do
        expect(result).to be_success
      end
    end

    context 'when the project secrets manager is not active' do
      subject(:result) { service.execute(name) }

      it 'returns an error' do
        expect(result).to be_error
        expect(result.message).to eq('Secrets manager is not active')
      end
    end
  end
end
