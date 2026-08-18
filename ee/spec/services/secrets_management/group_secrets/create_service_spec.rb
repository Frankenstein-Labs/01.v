# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecrets::CreateService, :gitlab_secrets_manager, feature_category: :secrets_management do
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:user) { create(:user) }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }
  let(:full_namespace_path) { secrets_manager.full_group_namespace_path }
  let(:service) { described_class.new(group, user) }
  let(:name) { 'TEST_SECRET' }
  let(:description) { 'test description' }
  let(:value) { 'the-secret-value' }
  let(:environment) { 'prod' }
  let(:protected) { true }
  let(:rotation_interval_days) { 30 }

  let(:execute_params) do
    {
      name: name,
      description: description,
      value: value,
      environment: environment,
      protected: protected,
      rotation_interval_days: rotation_interval_days
    }
  end

  subject(:result) { service.execute(**execute_params) }

  before_all do
    group.add_owner(user)
  end

  def provision_secrets_manager(secrets_manager, user)
    provision_group_secrets_manager(secrets_manager, user)
  end

  def rotation_info_for_secret(resource, name, version = 1)
    secret_rotation_info_for_group_secret(resource, name, version)
  end

  def rotation_info_count
    SecretsManagement::GroupSecretRotationInfo.count
  end

  it_behaves_like 'a service for creating a secret', 'group'

  describe '#execute', :aggregate_failures, :freeze_time do
    before do
      provision_secrets_manager(secrets_manager, user)
    end

    it 'creates a group secret with correct attributes' do
      expect(result).to be_success
      secret = result.payload[:secret]
      expect(secret.group).to eq(group)
      expect(secret.environment).to eq(environment)
      expect(secret.protected).to be true

      expect_kv_secret_to_have_custom_metadata(
        group.secrets_manager.full_group_namespace_path,
        group.secrets_manager.ci_secrets_mount_path,
        secrets_manager.ci_data_path(name),
        "environment" => environment,
        "protected" => "true"
      )
    end

    it 'creates the correct policy for the secret' do
      expect(result).to be_success

      # Validate correct policy has path
      expected_policy_name = group.secrets_manager.ci_policy_name_for_environment(environment, protected: protected)

      client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
      actual_policy = client.get_policy(expected_policy_name)
      expect(actual_policy).not_to be_nil

      expected_path = group.secrets_manager.ci_full_path(name)
      expect(actual_policy.paths).to include(expected_path)
      expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))

      expected_path = group.secrets_manager.ci_metadata_full_path(name)
      expect(actual_policy.paths).to include(expected_path)
      expect(actual_policy.paths[expected_path].capabilities).to eq(Set.new(["read"]))
    end

    context 'when protected is false' do
      let(:protected) { false }

      it 'creates the correct policy and custom metadata' do
        expect(result).to be_success

        expected_policy_name = group.secrets_manager.ci_policy_name_for_environment(environment, protected: false)

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        actual_policy = client.get_policy(expected_policy_name)
        expect(actual_policy).not_to be_nil

        expected_path = group.secrets_manager.ci_full_path(name)
        expect(actual_policy.paths).to include(expected_path)

        expect_kv_secret_to_have_custom_metadata(
          group.secrets_manager.full_group_namespace_path,
          group.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "protected" => "false"
        )
      end
    end

    context 'when using any environment' do
      let(:environment) { '*' }

      it 'creates the correct policy and custom metadata' do
        expect(result).to be_success

        expected_policy_name = group.secrets_manager.ci_policy_name_for_environment('*', protected: protected)

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        actual_policy = client.get_policy(expected_policy_name)
        expect(actual_policy).not_to be_nil

        expected_path = group.secrets_manager.ci_full_path(name)
        expect(actual_policy.paths).to include(expected_path)

        expect_kv_secret_to_have_custom_metadata(
          group.secrets_manager.full_group_namespace_path,
          group.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name),
          "environment" => environment
        )
      end
    end

    context 'when environment is not provided' do
      let(:environment) { '' }

      it 'fails' do
        expect(result).to be_error
        expect(result.message).to eq("Environment can't be blank")
      end
    end

    context 'when protected is nil' do
      let(:protected) { nil }

      it 'fails' do
        expect(result).to be_error
        expect(result.message).to include('is not included in the list')
      end
    end
  end
end
