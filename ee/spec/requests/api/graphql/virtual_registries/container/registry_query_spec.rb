# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying a container virtual registry', :aggregate_failures, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:registry) { create(:virtual_registries_container_registry, :with_upstreams, group: group) }

  let(:global_id) { registry.to_gid }
  let(:query) do
    <<~GRAPHQL
      {
        virtualRegistriesContainerRegistry(id: "#{global_id}") {
          id
          name
          registryUpstreams {
            id
            position
            upstream {
              id
              name
              registriesCount
            }
          }
        }
      }
    GRAPHQL
  end

  let(:container_registry_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['virtualRegistriesContainerRegistry']
  end

  let(:virtual_registry_available) { false }

  shared_examples 'returns null for virtualRegistriesContainerRegistry' do
    it 'returns null for the virtualRegistriesContainerRegistry field' do
      expect(container_registry_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Container).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for virtualRegistriesContainerRegistry'
  end

  context 'when user has access' do
    before_all do
      group.add_guest(current_user)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for virtualRegistriesContainerRegistry'
    end

    context 'when virtual registry is available' do
      let(:virtual_registry_available) { true }

      context 'when registry exists' do
        it 'returns registry for the containerVirtualRegistry field' do
          expect(container_registry_response['name']).to eq(registry.name)
        end

        it 'returns registry upstreams with upstream information' do
          registry_upstreams = container_registry_response['registryUpstreams']
          expect(registry_upstreams.length).to be 1
          expect(registry_upstreams[0]['position']).to be 1

          upstream = registry_upstreams[0]['upstream']
          expect(upstream).to include(
            'name' => 'name',
            'registriesCount' => 1
          )
        end
      end

      context 'when multiple upstreams exist' do
        let_it_be(:first_user) { create(:user) }
        let_it_be(:second_user) { create(:user) }

        before_all do
          group.add_guest(first_user)
          group.add_guest(second_user)
        end

        it 'avoids N+1 queries' do
          control_count = ActiveRecord::QueryRecorder.new do
            post_graphql(query, current_user: first_user)
          end

          registry1 = create(:virtual_registries_container_registry, group: group, name: 'test registry1')
          create(:virtual_registries_container_upstream, registries: [registry, registry1], name: 'test upstream1')

          expect do
            post_graphql(query, current_user: second_user)
          end.not_to exceed_query_limit(control_count)
          expect_graphql_errors_to_be_empty
        end

        it 'returns correct registriesCount for upstreams with multiple registries' do
          registry1 = create(:virtual_registries_container_registry, group: group, name: 'test registry1')
          registry2 = create(:virtual_registries_container_registry, group: group, name: 'test registry2')
          create(:virtual_registries_container_upstream, registries: [registry, registry1, registry2],
            name: 'multi-registry upstream')

          query_with_multiple = <<~GRAPHQL
            {
              virtualRegistriesContainerRegistry(id: "#{registry.to_gid}") {
                registryUpstreams {
                  upstream {
                    id
                    name
                    registriesCount
                  }
                }
              }
            }
          GRAPHQL

          post_graphql(query_with_multiple, current_user: current_user)
          upstreams = graphql_data['virtualRegistriesContainerRegistry']['registryUpstreams']
          expect(upstreams.length).to eq(2)

          multi_registry_upstream = upstreams.find { |u| u['upstream']['name'] == 'multi-registry upstream' }
          expect(multi_registry_upstream['upstream']['registriesCount']).to eq(3)
          expect_graphql_errors_to_be_empty
        end
      end

      context 'when registry does not exist' do
        let(:global_id) { "gid://gitlab/VirtualRegistries::Container::Registry/#{non_existing_record_id}" }

        it_behaves_like 'returns null for virtualRegistriesContainerRegistry'
      end
    end
  end
end
