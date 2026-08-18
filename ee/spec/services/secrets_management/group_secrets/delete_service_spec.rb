# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::GroupSecrets::DeleteService, :gitlab_secrets_manager, feature_category: :secrets_management do
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

  let(:execute_params) { name }

  subject(:result) { service.execute(execute_params) }

  before_all do
    group.add_owner(user)
  end

  def provision_secrets_manager(secrets_manager, user)
    provision_group_secrets_manager(secrets_manager, user)
  end

  def create_initial_secret
    SecretsManagement::GroupSecrets::CreateService.new(group, user).execute(
      name: name,
      description: description,
      value: value,
      environment: environment,
      protected: protected
    )
  end

  it_behaves_like 'a service for deleting a secret', 'group'

  describe '#execute', :aggregate_failures do
    before do
      provision_secrets_manager(secrets_manager, user)
      create_initial_secret
    end

    context 'when the secret exists' do
      it 'deletes a group secret and cleans up everything' do
        expect(result).to be_success
        expect(result.payload[:secret]).to be_present
        expect(result.payload[:secret].name).to eq(name)
        expect(result.payload[:secret].description).to eq(description)
        expect(result.payload[:secret].environment).to eq(environment)
        expect(result.payload[:secret].protected).to be true

        expect_kv_secret_not_to_exist(
          group.secrets_manager.full_group_namespace_path,
          group.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name)
        )

        # Since this was the only secret, the policy should be completely deleted
        policy_name = group.secrets_manager.ci_policy_name_for_environment(environment, protected: protected)
        expect_policy_not_to_exist(
          group.secrets_manager.full_group_namespace_path,
          policy_name
        )
      end
    end

    context 'when multiple secrets share the same policy' do
      let(:second_secret_name) { 'SECOND_SECRET' }
      let(:second_secret_environment) { environment }

      let(:second_secret_protected) { protected }

      before do
        # Create a second secret with the same environment and protected flag
        # This will share the same policy as the first secret
        SecretsManagement::GroupSecrets::CreateService.new(group, user).execute(
          name: second_secret_name,
          value: 'second-value',
          environment: second_secret_environment,
          protected: second_secret_protected,
          description: 'Second secret'
        )
      end

      it 'deletes the secret but preserves the policy with remaining secret paths' do
        expect(result).to be_success

        expect_kv_secret_not_to_exist(
          group.secrets_manager.full_group_namespace_path,
          group.secrets_manager.ci_secrets_mount_path,
          secrets_manager.ci_data_path(name)
        )

        policy_name = group.secrets_manager.ci_policy_name_for_environment(environment, protected: protected)

        client = secrets_manager_client.with_namespace(secrets_manager.full_group_namespace_path)
        updated_policy = client.get_policy(policy_name)
        expect(updated_policy).to be_present

        # First secret paths should be removed from the policy
        first_path = group.secrets_manager.ci_full_path(name)
        expect(updated_policy.paths.keys).not_to include(first_path)

        # Second secret should still have its paths and capabilities
        second_path = group.secrets_manager.ci_full_path(second_secret_name)
        expect(updated_policy.paths[second_path].capabilities).to include('read')
      end
    end

    context 'when deleting with different environment and protected combinations' do
      context 'when environment is wildcard' do
        let(:environment) { '*' }

        it 'deletes the secret and cleans up the policy' do
          expect(result).to be_success

          expect_kv_secret_not_to_exist(
            group.secrets_manager.full_group_namespace_path,
            group.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name)
          )

          policy_name = group.secrets_manager.ci_policy_name_for_environment('*', protected: protected)
          expect_policy_not_to_exist(
            group.secrets_manager.full_group_namespace_path,
            policy_name
          )
        end
      end

      context 'when protected is false' do
        let(:protected) { false }

        it 'deletes the secret and cleans up the correct policy' do
          expect(result).to be_success

          expect_kv_secret_not_to_exist(
            group.secrets_manager.full_group_namespace_path,
            group.secrets_manager.ci_secrets_mount_path,
            secrets_manager.ci_data_path(name)
          )

          policy_name = group.secrets_manager.ci_policy_name_for_environment(environment, protected: false)
          expect_policy_not_to_exist(
            group.secrets_manager.full_group_namespace_path,
            policy_name
          )
        end
      end
    end
  end
end
