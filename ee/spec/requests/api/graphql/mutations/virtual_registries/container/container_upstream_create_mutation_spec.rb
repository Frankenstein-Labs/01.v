# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create an upstream registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }

  let(:mutation_params) do
    {
      id: ::Gitlab::GlobalId.as_global_id(registry.id,
        model_name: 'VirtualRegistries::Container::Registry'),
      name: 'Docker Central',
      url: 'https://docker.io',
      cache_validity_hours: 24
    }
  end

  let(:faulty_mutation_params) do
    {
      **mutation_params,
      url: 'file://docker.io',
      cache_validity_hours: 'no'
    }
  end

  let(:mutation_response) { graphql_mutation_response(:container_upstream_create) }

  def container_upstream_mutation(params = mutation_params)
    graphql_mutation(:containerUpstreamCreate, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :create_container_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerUpstreamCreate, mutation_params, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  it 'creates the container upstream registry' do
    post_graphql_mutation(container_upstream_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['upstream']).to match(
      a_hash_including(
        "name" => 'Docker Central',
        "cacheValidityHours" => 24,
        "url" => 'https://docker.io',
        "registryUpstreams" => [a_hash_including(
          "position" => 1
        )]
      )
    )
  end

  it 'returns an error if the mutation params are invalid' do
    error_msg = "Variable $containerUpstreamCreateInput of type ContainerUpstreamCreateInput! " \
      "was provided invalid value for cacheValidityHours (Could not coerce value \"no\" to Int)"

    post_graphql_mutation(container_upstream_mutation(faulty_mutation_params), current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(graphql_errors[0]['message']).to eq(error_msg)
  end

  context 'with container_virtual_registries feature flag turned off' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it 'raises an exception' do
      error_msg = "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
      post_graphql_mutation(container_upstream_mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end
end
