# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Associates a upstream to a container virtual registry', feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: group) }

  let(:mutation_params) do
    {
      registry_id: registry.to_global_id,
      upstream_id: upstream.to_global_id
    }
  end

  let(:mutation_response) { graphql_mutation_response(:container_virtual_registry_upstream_create) }

  def container_virtual_registry_upstream_mutation(params = mutation_params)
    graphql_mutation(:containerVirtualRegistryUpstreamCreate, params)
  end

  before_all do
    group.add_owner(current_user)
  end

  before do
    stub_config(dependency_proxy: { enabled: true })
    stub_licensed_features(container_virtual_registry: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL',
    :associate_container_virtual_registry_upstream do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) { graphql_mutation(:containerVirtualRegistryUpstreamCreate, mutation_params, 'errors') }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  context 'when a granular token scoped to the registry group targets an upstream in another group' do
    let_it_be(:other_group) { create(:group) }
    let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: other_group) }

    let(:assignables) do
      ::Authz::PermissionGroups::Assignable
        .for_permission(:associate_container_virtual_registry_upstream).map(&:name).uniq
    end

    let(:pat) do
      create(:granular_pat, user: current_user, boundary: ::Authz::Boundary.for(group), permissions: assignables)
    end

    let(:mutation) { graphql_mutation(:containerVirtualRegistryUpstreamCreate, mutation_params, 'errors') }

    before_all do
      other_group.add_owner(current_user)
    end

    # The directive only checks the boundary of `registry_id`. The group
    # mismatch is rejected by VirtualRegistries::CreateRegistryUpstreamService,
    # which this example pins from the token angle.
    it 'denies the cross-group association' do
      post_graphql_mutation(mutation, token: { personal_access_token: pat })

      expect(graphql_errors).to include(
        a_hash_including('message' => include("The resource that you are attempting to access does not exist"))
      )
      expect(::VirtualRegistries::Container::RegistryUpstream.where(registry: registry, upstream: upstream)).to be_empty
    end
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

  it 'creates the container upstream registry' do
    post_graphql_mutation(container_virtual_registry_upstream_mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['registryUpstream']).to match(
      a_hash_including(
        "position" => 1
      )
    )
  end

  context 'when registry and upstream does not exist' do
    let(:mutation_params) do
      {
        registry_id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
          model_name: 'VirtualRegistries::Container::Registry'),
        upstream_id: ::Gitlab::GlobalId.as_global_id(non_existing_record_id,
          model_name: 'VirtualRegistries::Container::Upstream')
      }
    end

    it_behaves_like 'returning error message'
  end

  context 'when upstream does not exist in group' do
    let_it_be(:upstream) { create(:virtual_registries_container_upstream, group: create(:group)) }

    it_behaves_like 'returning error message'
  end

  context 'when max upstreams per registry is reached' do
    before_all do
      create_list(:virtual_registries_container_registry_upstream,
        VirtualRegistries::Container::RegistryUpstream::MAX_UPSTREAMS_COUNT,
        registry: registry)
    end

    it 'returns error message' do
      post_graphql_mutation(container_virtual_registry_upstream_mutation, current_user: current_user)

      expect(mutation_response['errors']).to include('Position must be less than or equal to 5')
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
