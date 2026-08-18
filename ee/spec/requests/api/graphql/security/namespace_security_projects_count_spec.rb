# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'NamespaceSecurityProjects count', feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: group) }
  let_it_be(:project1) { create(:project, namespace: group, name: 'A') }
  let_it_be(:project2) { create(:project, namespace: group, name: 'B') }
  let_it_be(:subgroup_project) { create(:project, namespace: subgroup, name: 'C') }
  let_it_be(:archived_project) { create(:project, :archived, namespace: group, name: 'D') }

  let_it_be(:filter1) { create(:security_inventory_filters, project: project1, critical: 5) }
  let_it_be(:filter2) { create(:security_inventory_filters, project: project2, critical: 0) }
  let_it_be(:filter3) { create(:security_inventory_filters, project: subgroup_project, critical: 9) }
  let_it_be(:archived_filter) { create(:security_inventory_filters, project: archived_project) }

  let(:filters) { '' }
  let(:selection) { 'count nodes { id }' }

  let(:query) do
    <<~GQL
      query {
        namespaceSecurityProjects(namespaceId: "#{group.to_global_id}"#{filters}) {
          #{selection}
        }
      }
    GQL
  end

  before_all do
    group.add_developer(current_user)
  end

  before do
    stub_licensed_features(security_inventory: true)
  end

  def count_and_nodes
    post_graphql(query, current_user: current_user)
    result = graphql_data['namespaceSecurityProjects']
    [result['count'], result['nodes']]
  end

  context 'with include_subgroups: true' do
    let(:filters) { ', includeSubgroups: true' }

    it 'returns count equal to the number of returned nodes (subtree, archived excluded)', :aggregate_failures do
      count, nodes = count_and_nodes

      expect(count).to eq(3)
      expect(count).to eq(nodes.size)
    end

    context 'with a vulnerability count filter' do
      let(:filters) do
        ', includeSubgroups: true, ' \
          'vulnerabilityCountFilters: [{ severity: CRITICAL, operator: GREATER_THAN_OR_EQUAL_TO, count: 1 }]'
      end

      it 'counts only matching projects', :aggregate_failures do
        count, nodes = count_and_nodes

        expect(count).to eq(2) # filter1 + filter3
        expect(count).to eq(nodes.size)
      end
    end
  end

  context 'with the default include_subgroups (false)' do
    it 'counts only direct children, equal to the returned nodes', :aggregate_failures do
      count, nodes = count_and_nodes

      expect(count).to eq(2)
      expect(count).to eq(nodes.size)
    end

    context 'when paginating' do
      let(:selection) { 'nodes { id } pageInfo { hasNextPage }' }
      let(:filters) { ', first: 2' }

      it 'returns the direct projects without reporting a stale next page', :aggregate_failures do
        post_graphql(query, current_user: current_user)
        data = graphql_data['namespaceSecurityProjects']

        expect(data['nodes'].size).to eq(2)
        expect(data.dig('pageInfo', 'hasNextPage')).to be(false)
      end
    end
  end
end
