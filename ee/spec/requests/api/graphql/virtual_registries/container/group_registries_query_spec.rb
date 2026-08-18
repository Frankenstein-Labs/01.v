# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying container virtual registries for top-level group', :aggregate_failures, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_container_upstream, registries: [registry]) }

  let(:full_path) { group.full_path }
  let(:query) do
    <<~GRAPHQL
      {
        group(fullPath: "#{full_path}") {
          virtualRegistriesContainerRegistries {
            count
            nodes {
              id
              name
              description
              updatedAt
            }
          }
        }
      }
    GRAPHQL
  end

  let(:container_registries_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['group']['virtualRegistriesContainerRegistries']
  end

  let(:virtual_registry_available) { false }

  shared_examples 'returns null for virtualRegistriesContainerRegistries' do
    it 'returns null for the virtualRegistriesContainerRegistries field' do
      expect(container_registries_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for virtualRegistriesContainerRegistries'
  end

  context 'when user has access' do
    before_all do
      group.add_guest(current_user)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for virtualRegistriesContainerRegistries'
    end

    context 'when virtual registry is available' do
      let(:virtual_registry_available) { true }

      it 'returns count for the virtualRegistriesContainerRegistries field' do
        expect(container_registries_response['count']).to eq(1)
      end

      it 'returns the virtualRegistriesContainerRegistries fields' do
        container_registries = container_registries_response['nodes']

        expect(container_registries[0]).to match(
          'id' => registry.to_global_id.to_s,
          'name' => registry.name,
          'description' => registry.description,
          'updatedAt' => registry.updated_at.iso8601
        )
      end
    end
  end
end
