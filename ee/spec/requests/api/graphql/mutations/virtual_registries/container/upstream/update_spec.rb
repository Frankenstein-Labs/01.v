# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a container upstream', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:mutation_params) do
    {
      id: upstream.to_global_id,
      name: 'New name',
      description: 'New description'
    }
  end

  let(:invalid_record_params) do
    {
      id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
        model_name: 'VirtualRegistries::Container::Upstream'),
      name: 'New name'
    }
  end

  let(:mutation_response) { graphql_mutation_response(:container_upstream_update) }

  def container_upstream_update_mutation(params = mutation_params)
    graphql_mutation(:containerUpstreamUpdate, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :update_container_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerUpstreamUpdate, mutation_params, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  shared_examples 'returning error message' do
    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  it 'updates the container upstream' do
    post_graphql_mutation(container_upstream_update_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['upstream']).to match(
      a_hash_including(
        "name" => 'New name',
        "description" => 'New description'
      )
    )
  end

  it_behaves_like 'returning error message' do
    let(:mutation) { container_upstream_update_mutation(invalid_record_params) }
  end

  context 'with container_virtual_registries feature flag turned off' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it_behaves_like 'returning error message' do
      let(:mutation) { container_upstream_update_mutation }
    end
  end
end
