# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying maven virtual registries for top-level group', :aggregate_failures, feature_category: :virtual_registry do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
  let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, registries: [registry]) }

  let(:full_path) { group.full_path }
  let(:query) do
    <<~GRAPHQL
      {
        group(fullPath: "#{full_path}") {
          virtualRegistriesPackagesMavenRegistries {
            count
            nodes {
              id
              name
            }
          }
        }
      }
    GRAPHQL
  end

  let(:maven_registries_response) do
    post_graphql(query, current_user: current_user)
    graphql_data['group']['virtualRegistriesPackagesMavenRegistries']
  end

  let(:virtual_registry_available) { false }

  shared_examples 'returns null for virtualRegistriesPackagesMavenRegistries' do
    it 'returns null for the virtualRegistriesPackagesMavenRegistries field' do
      expect(maven_registries_response).to be_nil
    end
  end

  before do
    allow(::VirtualRegistries::Packages::Maven).to receive(:virtual_registry_available?)
      .and_return(virtual_registry_available)
  end

  context 'when user does not have access' do
    it_behaves_like 'returns null for virtualRegistriesPackagesMavenRegistries'
  end

  context 'when user has access' do
    before_all do
      group.add_guest(current_user)
    end

    context 'when virtual registry is unavailable' do
      it_behaves_like 'returns null for virtualRegistriesPackagesMavenRegistries'
    end

    context 'when virtual registry is available' do
      let(:virtual_registry_available) { true }

      it 'returns name for the virtualRegistriesPackagesMavenRegistries field' do
        maven_registries = maven_registries_response['nodes']

        expect(maven_registries[0]['name']).to eq(registry.name)
      end

      it 'returns count for the virtualRegistriesPackagesMavenRegistries field' do
        expect(maven_registries_response['count']).to eq(1)
      end
    end
  end
end
