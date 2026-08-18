# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying container virtual upstreams for top-level group', :aggregate_failures, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
  let_it_be(:upstream1) do
    create(:virtual_registries_container_upstream, registries: [registry], name: 'upstream1')
  end

  let_it_be(:upstream2) do
    create(:virtual_registries_container_upstream, registries: [registry], name: 'upstream2')
  end

  let(:full_path) { group.full_path }
  let(:query) do
    <<~GRAPHQL
      {
        group(fullPath: "#{full_path}") {
          virtualRegistriesContainerUpstreams {
            count
            nodes {
              id
              url
              cacheValidityHours
              username
              name
              description
              registriesCount
            }
          }
        }
      }
    GRAPHQL
  end

  let(:container_upstreams_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['group']['virtualRegistriesContainerUpstreams']
  end

  let(:feature_enabled) { false }

  shared_examples 'returns null for virtualRegistriesContainerUpstreams' do
    it 'returns null for the virtualRegistriesContainerUpstreams field' do
      expect(container_upstreams_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Container).to receive(:feature_enabled?).and_return(feature_enabled)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for virtualRegistriesContainerUpstreams'
  end

  context 'when user has access' do
    before_all do
      group.add_guest(current_user)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for virtualRegistriesContainerUpstreams'
    end

    context 'when virtual registry is available' do
      let(:feature_enabled) { true }

      it 'returns count for the virtualRegistriesContainerUpstreams field' do
        expect(container_upstreams_response['count']).to eq(2)
      end

      context 'with guest access' do
        it 'returns the virtualRegistriesContainerUpstreams fields with username nil' do
          container_upstreams = container_upstreams_response['nodes']

          expect(container_upstreams).to match_array([
            {
              'id' => upstream1.to_global_id.to_s,
              'url' => upstream1.url,
              'cacheValidityHours' => upstream1.cache_validity_hours,
              'username' => nil,
              'name' => upstream1.name,
              'description' => upstream1.description,
              'registriesCount' => 1
            },
            {
              'id' => upstream2.to_global_id.to_s,
              'url' => upstream2.url,
              'cacheValidityHours' => upstream2.cache_validity_hours,
              'username' => nil,
              'name' => upstream2.name,
              'description' => upstream2.description,
              'registriesCount' => 1
            }
          ])
        end
      end

      context 'with maintainer access' do
        before_all do
          group.add_maintainer(current_user)
        end

        it 'returns the username field value' do
          container_upstreams = container_upstreams_response['nodes']

          expect(container_upstreams).to match_array([
            hash_including('username' => upstream1.username),
            hash_including('username' => upstream2.username)
          ])
        end
      end

      context 'when search by upstream name' do
        let(:upstream_name) { upstream1.name }
        let(:query) do
          <<~GRAPHQL
            {
              group(fullPath: "#{full_path}") {
                virtualRegistriesContainerUpstreams(upstreamName: "#{upstream_name}") {
                  nodes {
                    id
                  }
                }
              }
            }
          GRAPHQL
        end

        it 'returns the virtualRegistriesContainerUpstreams fields' do
          container_upstreams = container_upstreams_response['nodes']

          expect(container_upstreams).to contain_exactly(
            { 'id' => upstream1.to_global_id.to_s }
          )
        end
      end
    end
  end
end
