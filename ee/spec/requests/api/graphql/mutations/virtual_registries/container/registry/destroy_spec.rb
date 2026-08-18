# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy a container registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }

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

  def container_delete_mutation(params = mutation_params)
    graphql_mutation(:containerVirtualRegistryDelete, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :delete_container_virtual_registry do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerVirtualRegistryDelete, mutation_params, 'errors') }
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

  it 'destroys the container registry' do
    expect do
      post_graphql_mutation(container_delete_mutation, current_user: current_user)
    end.to change { ::VirtualRegistries::Container::Registry.count }.by(-1)
  end

  context 'when mutation params are invalid' do
    it_behaves_like 'returning error message' do
      let(:mutation) { container_delete_mutation(faulty_mutation_params) }
      let(:error_msg) do
        "Variable $containerVirtualRegistryDeleteInput of type ContainerVirtualRegistryDeleteInput! " \
          "was provided invalid value for id (Expected value to not be null)"
      end
    end
  end

  it_behaves_like 'returning error message' do
    let(:mutation) { container_delete_mutation(invalid_record_params) }
  end

  context 'with container_virtual_registries feature flag turned off' do
    before do
      stub_feature_flags(container_virtual_registries: false)
    end

    it_behaves_like 'returning error message' do
      let(:mutation) { container_delete_mutation }
    end
  end
end
