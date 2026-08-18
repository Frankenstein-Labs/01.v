# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update an upstream registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let(:mutation_response) { graphql_mutation_response(:maven_upstream_update) }
  let(:params) do
    {
      id: upstream.to_global_id,
      name: 'Maven Central',
      url: 'https://repo.maven.apache.org/maven2',
      cache_validity_hours: 24
    }
  end

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

  subject(:mutation) do
    post_graphql_mutation(graphql_mutation(:mavenUpstreamUpdate, params), current_user: current_user)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :update_maven_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:mavenUpstreamUpdate, params) }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  it 'updates the maven upstream registry' do
    mutation

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['upstream']).to match(
      a_hash_including(
        "name" => 'Maven Central',
        "cacheValidityHours" => 24,
        "url" => 'https://repo.maven.apache.org/maven2',
        "registryUpstreams" => [a_hash_including(
          "position" => 1
        )]
      )
    )
  end

  context 'when params are invalid' do
    let(:params) { super().merge(metadata_cache_validity_hours: 'no') }
    let(:error_msg) { /was provided invalid value for metadataCacheValidityHours/ }

    it 'returns an error' do
      mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to include(a_hash_including('message' => match(error_msg)))
    end
  end

  context 'with maven_virtual_registry feature flag turned off' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    let(:error_msg) do
      "The resource that you are attempting to access does " \
        "not exist or you don't have permission to perform this action"
    end

    it 'raises an exception' do
      mutation
      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end
end
