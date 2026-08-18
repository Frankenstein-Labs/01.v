# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Disassociates a upstream to a container virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group) }
  let_it_be(:registry_upstream) { create(:virtual_registries_container_registry_upstream, registry:, upstream:) }
  let_it_be(:registry_upstream2) { create(:virtual_registries_container_registry_upstream, registry:) }

  let(:mutation_params) do
    {
      upstream_id: registry_upstream.to_global_id
    }
  end

  let(:mutation_response) { graphql_mutation_response(:container_virtual_registry_upstream_delete) }

  def container_virtual_registry_upstream_mutation(params = mutation_params)
    graphql_mutation(:containerVirtualRegistryUpstreamDelete, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :disassociate_container_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerVirtualRegistryUpstreamDelete, mutation_params, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  shared_examples 'returning error message' do
    let(:mutation) { container_virtual_registry_upstream_mutation }
    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  it 'destroys the container upstream registry' do
    expect do
      post_graphql_mutation(container_virtual_registry_upstream_mutation, current_user: current_user)
    end.to change { ::VirtualRegistries::Container::RegistryUpstream.count }.by(-1)
  end

  it 'syncs the positions' do
    expect do
      post_graphql_mutation(container_virtual_registry_upstream_mutation, current_user: current_user)
    end.to change { registry_upstream2.reload.position }.by(-1)
  end

  context 'when upstream does not exist' do
    let(:mutation_params) do
      {
        upstream_id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
          model_name: 'VirtualRegistries::Container::RegistryUpstream')
      }
    end

    it_behaves_like 'returning error message'
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
