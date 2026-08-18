# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a maven virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }

  let(:params) do
    {
      id: id,
      name: 'New name',
      description: 'New description'
    }
  end

  let(:invalid_id) do
    global_id_of(id: non_existing_record_id, model_name: 'VirtualRegistries::Packages::Maven::Registry')
  end

  let(:id) { global_id_of(registry) }
  let(:error_msg) do
    "The resource that you are attempting to access does " \
      "not exist or you don't have permission to perform this action"
  end

  let(:mutation_response) { graphql_mutation_response(:maven_virtual_registry_update) }

  subject(:mutation) { post_graphql_mutation(graphql_mutation(:mavenVirtualRegistryUpdate, params), current_user:) }

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(packages_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :update_maven_virtual_registry do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:mavenVirtualRegistryUpdate, params) }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  it 'updates the maven virtual registry' do
    mutation

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['registry']).to match(
      a_hash_including(
        "name" => 'New name',
        "description" => 'New description'
      )
    )
  end

  context 'when no params are provided' do
    let(:params) { { id: } }

    it 'returns an error' do
      mutation

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to include('Invalid parameters provided')
    end
  end

  context 'with an invalid registry id' do
    let(:params) { super().merge(id: invalid_id) }

    it 'raises an exception' do
      mutation

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  context 'when packages_virtual_registry licensed feature is unavailable' do
    before do
      stub_licensed_features(packages_virtual_registry: false)
    end

    it 'raises an exception' do
      mutation

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end

  context 'with maven_virtual_registry feature flag turned off' do
    before do
      stub_feature_flags(maven_virtual_registry: false)
    end

    it 'raises an exception' do
      mutation

      expect(graphql_errors).to include(a_hash_including('message' => error_msg))
    end
  end
end
