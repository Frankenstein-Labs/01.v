# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Disassociates a upstream from a Maven virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, group: group) }
  let_it_be(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry:, upstream:) }
  let_it_be(:registry_upstream2) { create(:virtual_registries_packages_maven_registry_upstream, registry:) }

  let(:mutation_params) do
    {
      upstream_id: registry_upstream.to_global_id
    }
  end

  let(:mutation_response) { graphql_mutation_response(:maven_virtual_registry_upstream_delete) }

  def maven_virtual_registry_upstream_mutation(params = mutation_params)
    graphql_mutation(:mavenVirtualRegistryUpstreamDelete, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :disassociate_maven_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { maven_virtual_registry_upstream_mutation }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  shared_examples 'returning error message' do
    let(:mutation) { maven_virtual_registry_upstream_mutation }
    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'returns an error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  it 'deletes the Maven upstream registry' do
    post_graphql_mutation(maven_virtual_registry_upstream_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['registryUpstream']).to be_present
    expect(VirtualRegistries::Packages::Maven::RegistryUpstream.find_by(id: registry_upstream.id)).to be_nil
  end

  it 'syncs higher positions' do
    post_graphql_mutation(maven_virtual_registry_upstream_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(registry_upstream2.reload.position).to eq(1)
  end

  context 'when registry upstream does not exist' do
    let(:mutation_params) do
      {
        upstream_id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
          model_name: 'VirtualRegistries::Packages::Maven::RegistryUpstream')
      }
    end

    it_behaves_like 'returning error message'
  end

  context 'with maven_virtual_registry feature flag turned off' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    it_behaves_like 'returning error message'
  end

  context 'when packages_virtual_registry licensed feature is unavailable' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
    end

    it_behaves_like 'returning error message'
  end
end
