# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- we need to test a lot of partial attribute changes
RSpec.describe SecretsManagement::ProjectSecrets::UpdateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:secrets_manager) { create(:project_secrets_manager, project: project) }
  let(:full_namespace_path) { secrets_manager.full_project_namespace_path }
  let(:service) { described_class.new(project, user) }

  let(:new_description) { 'updated description' }
  let(:new_value) { 'updated-secret-value' }
  let(:new_branch) { 'feature' }
  let(:new_environment) { 'staging' }
  let(:new_rotation_interval_days) { 30 }

  let(:original_name) { 'TEST_SECRET' }
  let(:original_description) { 'test description' }
  let(:original_value) { 'the-secret-value' }
  let(:original_branch) { 'main' }
  let(:original_environment) { 'prod' }
  let(:original_rotation_interval_days) { nil }

  let(:name) { original_name }
  let(:description) { nil }
  let(:value) { nil }
  let(:branch) { nil }
  let(:environment) { nil }
  let(:rotation_interval_days) { nil }
  let(:initial_metadata_version) { 2 }
  let(:metadata_cas) { initial_metadata_version }
  let(:expected_version_after_update) { initial_metadata_version + 1 }
  let(:version_on_create) { 1 }

  let(:execute_params) do
    {
      name: name,
      description: description,
      value: value,
      branch: branch,
      environment: environment,
      rotation_interval_days: rotation_interval_days,
      metadata_cas: metadata_cas
    }
  end

  subject(:result) { service.execute(**execute_params) }

  before_all do
    project.add_owner(user)
  end

  def provision_secrets_manager(secrets_manager, user)
    provision_project_secrets_manager(secrets_manager, user)
  end

  def rotation_info_for_secret(resource, name, version = 1)
    secret_rotation_info_for_project_secret(resource, name, version)
  end

  def create_initial_secret
    create_project_secret(
      user: user,
      project: project,
      name: original_name,
      description: original_description,
      value: original_value,
      branch: original_branch,
      environment: original_environment,
      rotation_interval_days: original_rotation_interval_days
    )
  end

  it_behaves_like 'a service for updating a secret', 'project'

  describe '#execute', :aggregate_failures, :freeze_time do
    before do
      provision_secrets_manager(secrets_manager, user)
      create_initial_secret
    end

    context 'with partial updates' do
      let(:description) { new_description }

      it 'updates only the description' do
        expect(result).to be_success
        expect(result.payload[:secret].description).to eq(new_description)
        expect(result.payload[:secret].metadata_version).to eq(initial_metadata_version + 1)

        # Verify metadata was updated
        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "description" => new_description
        )

        # Verify value is unchanged
        expect_kv_secret_to_have_value(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          original_value
        )

        # Verify policies are unchanged
        client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
        policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
        policy = client.get_policy(policy_name)
        expect(policy.paths).to include(project.secrets_manager.ci_full_path(name))
      end
    end

    context 'with value update' do
      let(:value) { new_value }

      it 'updates the value' do
        expect(result).to be_success
        expect(result.payload[:secret].metadata_version).to eq(expected_version_after_update)

        # Verify the value was updated
        expect_kv_secret_to_have_value(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          new_value
        )

        # Verify metadata is unchanged except version
        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "description" => original_description,
          "environment" => original_environment,
          "branch" => original_branch
        )
      end
    end

    context 'when secrets creation is in progress', :freeze_time do
      let(:description) { new_description }
      let(:mount) { project.secrets_manager.ci_secrets_mount_path }

      it 'fails to update' do
        client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)

        client.update_kv_secret_metadata(
          mount,
          project.secrets_manager.ci_data_path(name),
          {
            description: 'Second secret',
            environment: 'staging',
            branch: 'staging'
          },
          metadata_cas: 2
        )

        expect(result).not_to be_success
        expect(result.message).to eq("Secret create in progress.")
      end
    end

    context 'when metadata timing fields are written', :freeze_time do
      let(:description) { new_description }

      it 'sets update_started_at and update_completed_at and bumps metadata twice' do
        frozen_iso = Time.current.utc.iso8601

        expect(result).to be_success

        expect_kv_secret_to_have_metadata_version(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          metadata_cas + 2
        )

        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "update_started_at" => frozen_iso,
          "update_completed_at" => frozen_iso
        )
      end

      context 'when metadata_cas is not given' do
        let(:description) { new_description }
        let(:metadata_cas) { nil }

        it 'sets both timestamps and uses previous version + 1 then + 2' do
          frozen_iso = Time.current.utc.iso8601
          expect(result).to be_success

          expect_kv_secret_to_have_metadata_version(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            initial_metadata_version + 2
          )

          expect_kv_secret_to_have_custom_metadata(
            project.secrets_manager.full_project_namespace_path,
            project.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name),
            "update_started_at" => frozen_iso,
            "update_completed_at" => frozen_iso
          )

          expect(result.payload[:secret].metadata_version).to be_nil
        end
      end
    end

    context 'when updating environment' do
      let(:environment) { new_environment }

      it 'updates the environment and policies' do
        expect(result).to be_success
        expect(result.payload[:secret].environment).to eq(new_environment)
        expect(result.payload[:secret].metadata_version).to eq(3)

        # Verify metadata was updated
        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "environment" => new_environment
        )

        # Verify old policy no longer contains the secret
        client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
        old_policy_name = project.secrets_manager.ci_policy_name(original_environment,
          original_branch)
        old_policy = client.get_policy(old_policy_name)

        expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

        # Verify new policy contains the secret
        new_policy_name = project.secrets_manager.ci_policy_name(new_environment, original_branch)
        new_policy = client.get_policy(new_policy_name)

        expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
      end
    end

    context 'when the original policy has no other secrets' do
      let(:environment) { new_environment }

      it 'removes the old policy entirely' do
        expect(result).to be_success

        # Verify the old policy has been completely deleted or is empty
        secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
        old_policy_name = project.secrets_manager.ci_policy_name(original_environment,
          original_branch)
        old_policy = secrets_manager_client.get_policy(old_policy_name)

        expect(old_policy.paths).to be_empty
      end
    end

    context 'when updating branch' do
      let(:branch) { new_branch }

      it 'updates the branch and policies' do
        expect(result).to be_success
        expect(result.payload[:secret].branch).to eq(new_branch)
        expect(result.payload[:secret].metadata_version).to eq(3)

        # Verify metadata was updated
        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "branch" => new_branch
        )

        # Verify old policy no longer contains the secret
        client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
        old_policy_name = project.secrets_manager.ci_policy_name(original_environment,
          original_branch)
        old_policy = client.get_policy(old_policy_name)

        expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

        # Verify new policy contains the secret
        new_policy_name = project.secrets_manager.ci_policy_name(original_environment, new_branch)
        new_policy = client.get_policy(new_policy_name)

        expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
      end
    end

    context 'when updating everything' do
      let(:description) { new_description }
      let(:value) { new_value }
      let(:branch) { new_branch }
      let(:environment) { new_environment }
      let(:rotation_interval_days) { new_rotation_interval_days }

      it 'updates all fields, policies, and adds rotation' do
        expect(result).to be_success

        secret = result.payload[:secret]
        expect(secret.description).to eq(new_description)
        expect(secret.branch).to eq(new_branch)
        expect(secret.environment).to eq(new_environment)
        expect(secret.metadata_version).to eq(3)

        # Verify rotation was added
        new_version = metadata_cas + 1
        rotation_info = secret_rotation_info_for_project_secret(project, name, new_version)
        expect(rotation_info).not_to be_nil
        expect(rotation_info.rotation_interval_days).to eq(new_rotation_interval_days)
        expect(secret.rotation_info).to eq(rotation_info)

        # Verify value was updated
        expect_kv_secret_to_have_value(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          new_value
        )

        # Verify metadata was updated
        expect_kv_secret_to_have_metadata_version(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          new_version + 1
        )

        expect_kv_secret_to_have_custom_metadata(
          project.secrets_manager.full_project_namespace_path,
          project.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "description" => new_description,
          "environment" => new_environment,
          "branch" => new_branch,
          "secret_rotation_info_id" => rotation_info.id.to_s
        )

        # Verify old policy no longer contains the secret
        client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
        old_policy_name = project.secrets_manager.ci_policy_name(original_environment,
          original_branch)
        old_policy = client.get_policy(old_policy_name)

        expect(old_policy.paths).not_to include(project.secrets_manager.ci_full_path(name))

        # Verify new policy contains the secret
        new_policy_name = project.secrets_manager.ci_policy_name(new_environment, new_branch)
        new_policy = client.get_policy(new_policy_name)

        expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
      end
    end

    context 'when updating environment or branch with wildcard patterns' do
      context 'when updating from non-wildcard to wildcard' do
        let(:branch) { 'feature/*' }
        let(:environment) { 'staging-*' }

        it 'moves the secret into the policy for the new wildcard pattern' do
          expect(result).to be_success

          client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
          new_policy_name = project.secrets_manager.ci_policy_name(environment, branch)
          new_policy = client.get_policy(new_policy_name)

          expect(new_policy.paths).to include(project.secrets_manager.ci_full_path(name))
        end
      end

      context 'when updating from wildcard to non-wildcard' do
        let(:original_branch) { 'feature/*' }
        let(:original_environment) { 'staging-*' }
        let(:environment) { 'production' }
        let(:branch) { 'master' }

        it 'deletes the now-empty wildcard policy' do
          expect(result).to be_success

          old_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
          expect_policy_not_to_exist(project.secrets_manager.full_project_namespace_path, old_policy_name)
        end

        context 'and other secrets are under the previous wildcards' do
          let(:second_secret_name) { 'SECOND_SECRET' }

          before do
            create_project_secret(
              user: user,
              project: project,
              name: second_secret_name,
              value: 'second-value',
              branch: original_branch,
              environment: original_environment,
              description: 'Second secret'
            )
          end

          it 'preserves the wildcard policy used by the other secret' do
            expect(result).to be_success

            client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
            shared_policy_name = project.secrets_manager.ci_policy_name(original_environment, original_branch)
            shared_policy = client.get_policy(shared_policy_name)

            expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(second_secret_name))
          end
        end
      end
    end

    context 'with invalid inputs' do
      context 'when branch is empty' do
        let(:branch) { '' }

        it 'returns an error' do
          expect(result).not_to be_success
          expect(result.message).to eq("Branch can't be blank")
        end

        context 'with rotation interval specified' do
          let(:rotation_interval_days) { new_rotation_interval_days }

          it 'does not create rotation info when validation fails' do
            expect(result).not_to be_success

            # No new rotation info should be created
            rotation_info = secret_rotation_info_for_project_secret(project, name, metadata_cas + 1)
            expect(rotation_info).to be_nil
          end
        end
      end
    end

    context 'when updating to share policy with another secret' do
      let(:second_secret_name) { 'SECOND_SECRET' }
      let(:environment) { 'shared-env' }  # Both secrets will share this environment
      let(:branch) { 'shared-branch' }    # Both secrets will share this branch

      before do
        # Create a second secret with the shared env/branch
        create_project_secret(
          user: user,
          project: project,
          name: second_secret_name,
          value: "second-value",
          branch: branch,
          environment: environment,
          description: "Second secret"
        )
      end

      it 'adds the secret to the shared policy' do
        expect(result).to be_success

        # Verify the shared policy has both secrets
        client = secrets_manager_client.with_namespace(project.secrets_manager.full_project_namespace_path)
        shared_policy_name = project.secrets_manager.ci_policy_name(environment, branch)
        shared_policy = client.get_policy(shared_policy_name)

        expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(name))
        expect(shared_policy.paths).to include(project.secrets_manager.ci_full_path(second_secret_name))
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
