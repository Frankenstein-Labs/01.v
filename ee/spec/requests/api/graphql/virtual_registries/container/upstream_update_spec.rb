# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a container virtual registry upstream', feature_category: :virtual_registry do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:mutation) { graphql_mutation(:container_upstream_update, params) }
  let(:mutation_response) { graphql_mutation_response(:container_upstream_update) }

  let(:upstream_global_id) do
    ::Gitlab::GlobalId.as_global_id(upstream.id, model_name: 'VirtualRegistries::Container::Upstream')
  end

  let(:params) do
    {
      id: upstream_global_id,
      name: 'Docker Central 2',
      description: 'Upstream description for Docker Central 2',
      url: 'https://quay.io',
      cache_validity_hours: 8
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(VirtualRegistries::Container).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when current_user has permission' do
    let(:virtual_registry_available) { true }

    before_all do
      group.add_owner(current_user)
    end

    it 'updates upstream for the group' do
      execute

      expect(upstream.reload).to have_attributes(params.except(:id))
    end

    context 'when container virtual registry is not available' do
      let(:virtual_registry_available) { false }

      it_behaves_like 'a mutation on an unauthorized resource'
    end
  end

  context 'when current_user has no permission' do
    let(:virtual_registry_available) { true }

    before_all do
      group.add_guest(current_user)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
  end
end
