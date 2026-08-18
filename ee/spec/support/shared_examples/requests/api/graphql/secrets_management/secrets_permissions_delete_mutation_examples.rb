# frozen_string_literal: true

RSpec.shared_examples 'a GraphQL mutation for deleting secrets permissions' do |resource_type|
  # Note: The including spec must define:
  # - resource (the project or group)
  # - current_user (the user making the request)
  # - mutation_name (the GraphQL mutation name)
  # - secrets_manager (the secrets manager instance)
  # - provision_secrets_manager (method to provision the secrets manager)
  # - params (the mutation parameters)
  # - service_class (the service class for deleting permissions)
  # - feature_flag_name (the feature flag name to check)
  # - update_permission (method to setup and create the permission to delete)

  let_it_be(:other_user, freeze: false) { create(:user) }

  let(:mutation) { graphql_mutation(mutation_name, params) }
  let(:mutation_response) { graphql_mutation_response(mutation_name) }
  let(:principal) { { id: other_user.id, type: 'User' } }

  subject(:post_mutation) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    provision_secrets_manager(secrets_manager, current_user)
  end

  context "when current user is not part of the #{resource_type}" do
    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context "when current user is not the #{resource_type} owner" do
    before do
      resource.add_maintainer(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end

  context 'when current user is an owner' do
    before do
      resource.add_maintainer(other_user)
      resource.add_owner(current_user)

      # Create a permission to delete
      update_permission(
        user: current_user,
        actions: %w[write read],
        principal: { id: principal[:id], type: principal[:type] }
      )
    end

    it 'deletes the secret permission', :aggregate_failures do
      post_mutation
      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end

    it 'triggers an internal event' do
      expected_attributes =
        if resource_type == 'project'
          {
            category: 'Mutations::SecretsManagement::ProjectSecretsPermissions::Delete',
            project: resource,
            namespace: resource.namespace
          }
        else
          {
            category: 'Mutations::SecretsManagement::GroupSecretsPermissions::Delete',
            namespace: resource
          }
        end

      expect { post_mutation }
        .to trigger_internal_events("delete_#{resource_type}_secrets_permission")
        .with(user: current_user, **expected_attributes)
    end

    it_behaves_like "an API request requiring an exclusive #{resource_type} secret operation lease"

    it_behaves_like 'a secrets manager mutation blocked on an inactive namespace' do
      let(:inactive_namespace) { resource }
    end

    it_behaves_like 'a secrets manager mutation blocked on entitlement' do
      let(:payload_key) { 'secretsPermission' }
    end
  end

  context 'and service results to a failure' do
    before do
      resource.add_owner(current_user)

      allow_next_instance_of(service_class) do |service|
        result = ServiceResponse.error(message: 'some error')
        allow(service).to receive(:execute).and_return(result)
      end
    end

    it 'returns the service error' do
      post_mutation

      expect(mutation_response['errors']).to include('some error')
    end

    it 'does not trigger an internal event' do
      expect { post_mutation }.not_to trigger_internal_events("delete_#{resource_type}_secrets_permission")
    end
  end

  context "and #{resource_type}_secrets_manager feature flag is disabled" do
    before do
      resource.add_owner(current_user)
      stub_feature_flags(feature_flag_name => false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
