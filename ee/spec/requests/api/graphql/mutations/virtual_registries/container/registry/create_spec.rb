# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a container virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }

  let(:mutation_params) do
    {
      group_path: group.full_path,
      name: 'Name',
      description: 'Description'
    }
  end

  let(:faulty_mutation_params) do
    {
      **mutation_params,
      name: nil
    }
  end

  let(:mutation_response) { graphql_mutation_response(:container_virtual_registry_create) }

  def container_virtual_registry_mutation(params = mutation_params)
    graphql_mutation(:containerVirtualRegistryCreate, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :create_container_virtual_registry do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerVirtualRegistryCreate, mutation_params, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  shared_examples 'returning error message' do
    let(:mutation) { container_virtual_registry_mutation }
    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  it 'creates the container upstream registry' do
    post_graphql_mutation(container_virtual_registry_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['registry']).to match(
      a_hash_including(
        "name" => 'Name',
        "description" => 'Description'
      )
    )
  end

  context 'when mutation params are invalid' do
    it_behaves_like 'returning error message' do
      let(:mutation) { container_virtual_registry_mutation(faulty_mutation_params) }
      let(:error_msg) do
        "Variable $containerVirtualRegistryCreateInput of type ContainerVirtualRegistryCreateInput! " \
          "was provided invalid value for name (Expected value to not be null)"
      end
    end
  end

  context 'with container_virtual_registries feature flag turned off' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it_behaves_like 'returning error message'
  end

  context 'when container_virtual_registry licensed feature is unavailable' do
    before do
      stub_licensed_features(container_virtual_registry: false)
    end

    it_behaves_like 'returning error message'
  end
end
