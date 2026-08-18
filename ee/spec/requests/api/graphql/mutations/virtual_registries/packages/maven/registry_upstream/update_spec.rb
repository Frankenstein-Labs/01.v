# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updates a Maven virtual registry upstream', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, group: group) }
  let_it_be(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry:, upstream:) }
  let_it_be(:registry_upstream2) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }

  let(:mutation_params) do
    {
      id: registry_upstream.to_global_id,
      position: 2
    }
  end

  let(:mutation_response) { graphql_mutation_response(:maven_virtual_registry_upstream_update) }

  subject(:mutation) do
    post_graphql_mutation(
      graphql_mutation(:mavenVirtualRegistryUpstreamUpdate, mutation_params),
      current_user: current_user
    )
  end

  before_all do
    group.add_maintainer(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :update_maven_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:mavenVirtualRegistryUpstreamUpdate, mutation_params) }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  shared_examples 'returning error message' do
    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'returns an error' do
      mutation

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  it 'updates a registry upstream position' do
    expect { mutation }.to change { registry_upstream.reload.position }.from(1).to(2)
  end

  it 'updates all registry upstream positions' do
    expect { mutation }.to change { registry_upstream2.reload.position }.from(2).to(1)
  end

  context 'when upstream does not exist' do
    let(:mutation_params) do
      {
        id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
          model_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream'),
        position: 1
      }
    end

    it_behaves_like 'returning error message'
  end

  context 'when position is not valid' do
    let(:mutation_params) do
      {
        id: registry_upstream.to_global_id,
        position: 100
      }
    end

    it 'returns mutation-level errors' do
      mutation

      expect(mutation_response).to include(
        'errors' => ["Position must be less than or equal to 20"]
      )
    end
  end

  context 'when packages_virtual_registry licensed feature is unavailable' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
    end

    it_behaves_like 'returning error message'
  end

  context 'with maven_virtual_registry feature flag turned off' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    it_behaves_like 'returning error message'
  end
end
