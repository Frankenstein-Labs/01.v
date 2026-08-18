# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update group secret', :gitlab_secrets_manager, :freeze_time, feature_category: :secrets_management do
  include GraphqlHelpers

  let_it_be_with_reload(:group) { create(:group) }
  let_it_be(:owner_user) { create(:user) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:mutation_name) { :group_secret_update }

  let(:secrets_manager) { create(:group_secrets_manager, group: group) }

  let(:group_secret_attributes) do
    {
      name: 'TEST_SECRET',
      description: 'test description',
      environment: 'production',
      protected: true,
      value: 'test value'
    }
  end

  let(:params) do
    {
      group_path: group.full_path,
      name: group_secret_attributes[:name],
      description: 'updated description',
      environment: 'staging',
      protected: false,
      metadata_cas: 2,
      rotation_interval_days: 30
    }
  end

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before_all do
    group.add_owner(owner_user)
  end

  before do
    stub_last_activity_update
    provision_group_secrets_manager(secrets_manager, owner_user)

    # Create initial secret
    SecretsManagement::GroupSecrets::CreateService.new(group, owner_user).execute(
      **group_secret_attributes
    )
  end

  after do
    cancel_exclusive_group_secret_operation_lease(group)
  end

  context 'when current user is not part of the group' do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user does not have write permissions in openbao' do
    before_all do
      group.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  shared_examples_for 'a successful update request' do
    it 'updates the group secret', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty

      expect(graphql_data_at(mutation_name, :group_secret))
        .to match(a_graphql_entity_for(
          group: a_graphql_entity_for(group),
          name: group_secret_attributes[:name],
          description: 'updated description',
          environment: 'staging',
          protected: false,
          metadata_version: 3,
          status: 'COMPLETED'
        ))
    end

    it 'creates the rotation info record', :aggregate_failures do
      post_mutation

      expect(response).to have_gitlab_http_status(:success)

      new_version = 3
      rotation_info = secret_rotation_info_for_group_secret(group, params[:name], new_version)
      expect(rotation_info).not_to be_nil
      expect(rotation_info.rotation_interval_days).to eq(params[:rotation_interval_days])
      expect(rotation_info.next_reminder_at).to be_present
    end

    it_behaves_like 'an API request requiring an exclusive group secret operation lease'

    it_behaves_like 'internal event tracking' do
      let(:event) { 'update_group_ci_secret' }
      let(:user) { current_user }
      let(:namespace) { group }
      let(:category) { 'Mutations::SecretsManagement::GroupSecrets::Update' }
    end
  end

  context 'when current user was granted write permissions in openbao' do
    before_all do
      group.add_maintainer(current_user)
    end

    before do
      update_group_secrets_permission(
        user: current_user, group: group, actions: %w[write read], principal: {
          id: Gitlab::Access.sym_options[:maintainer], type: 'Role'
        }
      )
    end

    it_behaves_like 'a successful update request'

    context 'with partial updates' do
      let(:params) do
        {
          group_path: group.full_path,
          name: group_secret_attributes[:name],
          description: 'updated description only',
          metadata_cas: 2
        }
      end

      it 'updates only the specified fields', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :group_secret))
          .to match(a_graphql_entity_for(
            name: group_secret_attributes[:name],
            description: 'updated description only',
            environment: group_secret_attributes[:environment],
            protected: group_secret_attributes[:protected],
            metadata_version: 3
          ))

        # Verify value wasn't changed
        secret_path = secrets_manager.ci_data_path(group_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          group.secrets_manager.full_group_namespace_path,
          group.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'test value'
        )
      end
    end

    context 'with value update' do
      let(:params) do
        {
          group_path: group.full_path,
          name: group_secret_attributes[:name],
          secret: 'new-secret-value',
          metadata_cas: 2
        }
      end

      it 'updates the value', :aggregate_failures do
        post_mutation

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty

        expect(graphql_data_at(mutation_name, :group_secret))
          .to match(a_graphql_entity_for(
            metadata_version: 3
          ))

        # Verify value was updated
        secret_path = secrets_manager.ci_data_path(group_secret_attributes[:name])
        expect_kv_secret_to_have_value(
          group.secrets_manager.full_group_namespace_path,
          group.secrets_manager.ci_secrets_mount_path,
          secret_path,
          'new-secret-value'
        )
      end
    end

    context 'when metadata_cas is not provided' do
      let(:params) do
        {
          group_path: group.full_path,
          name: group_secret_attributes[:name],
          description: 'updated description'
        }
      end

      it 'returns an error', :aggregate_failures do
        post_mutation

        expect_graphql_errors_to_include(
          "GroupSecretUpdateInput! was provided invalid value for metadataCas"
        )
      end
    end

    context 'when secret does not exist' do
      let(:params) do
        {
          group_path: group.full_path,
          name: 'NON_EXISTENT_SECRET',
          description: 'updated description',
          metadata_cas: 2
        }
      end

      it 'returns a top-level error with message' do
        post_mutation

        expect(mutation_response).to be_nil
        expect(graphql_errors.count).to eq(1)
        expect(graphql_errors.first['message']).to eq('Group secret does not exist.')
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and service results to a failure' do
      let(:params) do
        {
          group_path: group.full_path,
          name: group_secret_attributes[:name],
          description: 'updated description',
          metadata_cas: 999
        }
      end

      it 'returns the service error' do
        post_mutation

        error_message = 'This secret has been modified recently. Please refresh the page and try again.'
        expect(mutation_response['errors']).to contain_exactly(error_message, error_message)
      end

      it_behaves_like 'internal event not tracked'
    end

    context 'and group_secrets_manager feature flag is disabled' do
      before do
        stub_feature_flags(group_secrets_manager: false)
      end

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when current user is group owner' do
    before_all do
      group.add_owner(current_user)
    end

    it_behaves_like 'a successful update request'

    it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
      let(:inactive_namespace) { group }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'groupSecret' }
      let(:service_class) { SecretsManagement::GroupSecrets::UpdateService }
    end
  end
end
