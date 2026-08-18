# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy a registries upstreams cache', :sidekiq_inline, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }
  let_it_be_with_reload(:cache) do
    create_list(:virtual_registries_container_cache_remote_entry, 2, upstream: upstream)
  end

  let_it_be(:cache2) { create_list(:virtual_registries_container_cache_remote_entry, 2) }

  let(:mutation_params) do
    {
      id: registry.to_global_id
    }
  end

  let(:faulty_mutation_params) do
    {
      id: nil
    }
  end

  let(:invalid_record_params) do
    {
      id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
        model_name: 'VirtualRegistries::Container::Registry')
    }
  end

  def registry_cache_delete_mutation(params = mutation_params)
    graphql_mutation(:containerVirtualRegistryCacheDelete, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :purge_container_virtual_registry_cache do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerVirtualRegistryCacheDelete, mutation_params, 'errors') }
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

  it 'destroys the cache' do
    expect do
      post_graphql_mutation(registry_cache_delete_mutation, current_user: current_user)
    end.to change { ::VirtualRegistries::Container::Cache::Remote::Entry.pending_destruction.count }.by(2)
  end

  context 'when mutation params are invalid' do
    it_behaves_like 'returning error message' do
      let(:mutation) { registry_cache_delete_mutation(faulty_mutation_params) }
      let(:error_msg) do
        "Variable $containerVirtualRegistryCacheDeleteInput of type ContainerVirtualRegistryCacheDeleteInput! " \
          "was provided invalid value for id (Expected value to not be null)"
      end
    end
  end

  it_behaves_like 'returning error message' do
    let(:mutation) { registry_cache_delete_mutation(invalid_record_params) }
  end

  context 'with container_virtual_registries feature flag turned off' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it_behaves_like 'returning error message' do
      let(:mutation) { registry_cache_delete_mutation }
    end
  end
end
