# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting consumed AI catalog items', feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:guest) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, :public, guests: guest, developers: developer) }
  let_it_be(:catalog_agents) { create_list(:ai_catalog_agent, 2) }
  let_it_be(:catalog_flows) { create_list(:ai_catalog_flow, 2) }
  let_it_be(:catalog_third_party_flows) { create_list(:ai_catalog_third_party_flow, 2) }
  let_it_be(:catalog_items) { [*catalog_agents, *catalog_flows, *configured_third_party_flows] }
  let_it_be(:configured_agents) do
    catalog_agents.map { |item| create(:ai_catalog_item_consumer, project: project, item: item) }
  end

  let_it_be(:configured_flows) do
    catalog_flows.map { |item| create(:ai_catalog_item_consumer, :child_item_consumer, project: project, item: item) }
  end

  let_it_be(:flow_triggers) do
    configured_flows.map do |ai_catalog_item_consumer|
      create(:ai_flow_trigger, :for_catalog_consumer, ai_catalog_item_consumer:, project:)
    end
  end

  let_it_be(:configured_third_party_flows) do
    catalog_third_party_flows.map { |item| create(:ai_catalog_item_consumer, project: project, item: item) }
  end

  let_it_be(:configured_items) do
    [*configured_agents, *configured_flows, *configured_third_party_flows]
  end

  let(:current_user) { developer }
  let(:project_gid) { project.to_global_id }
  let(:nodes) { graphql_data_at(:ai_catalog_configured_items, :nodes) }
  let(:args) { { projectId: project_gid } }
  let(:excluded_fields) { [] }
  let(:fields) { all_graphql_fields_for('AiCatalogItemConsumer', max_depth: 3, excluded: excluded_fields) }
  let(:query) do
    "{ #{query_nodes('aiCatalogConfiguredItems', fields, args: args)} }"
  end

  before do
    enable_ai_catalog
  end

  context 'with at least guest access in the project' do
    # ItemConsumersFinder filters out results for flow and third party flow items if the user
    # does not have permission, which requires developer+ of the project.
    let(:expected_items) { configured_items.reject { |i| i.item.flow? || i.item.third_party_flow? } }
    let(:current_user) { guest }

    it 'returns configured AI catalog items excluding flows and third party flows' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to match_array(expected_items.map { |configured_item| a_graphql_entity_for(configured_item) })
    end
  end

  context 'with at least developer access in the project' do
    it 'returns all configured AI catalog items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to match_array(configured_items.map { |configured_item| a_graphql_entity_for(configured_item) })
    end
  end

  context 'when filtering by group and item' do
    let_it_be(:group) { create(:group, guests: guest, developers: developer) }
    let_it_be(:configured_items) do
      catalog_items.map { |item| create(:ai_catalog_item_consumer, group: group, item: item) }
    end

    let(:args) { { groupId: group.to_global_id, itemId: configured_items[0].item.to_global_id } }

    it 'returns configured AI catalog items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to contain_exactly(a_graphql_entity_for(configured_items[0]))
    end

    context 'with guest access' do
      let(:current_user) { guest }
      let(:flow) { configured_items.find { |i| i.item.flow? }.item }

      let(:args) { { groupId: group.to_global_id, itemId: flow.to_global_id } }

      it 'does not return flow items' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(nodes).to be_empty
      end
    end
  end

  describe 'N+1 optimization' do
    # We know pinnedItemVersion generates N+1 queries, so exclude it.
    # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/212515#note_2885414833
    let(:excluded_fields) { ['pinnedItemVersion'] }

    it 'avoids N+1 queries' do
      # Warm up the cache
      post_graphql(query, current_user: current_user)

      control = ActiveRecord::QueryRecorder.new { post_graphql(query, current_user: current_user) }

      create(:ai_catalog_item_consumer, project: project)

      expect { post_graphql(query, current_user: current_user) }.not_to exceed_query_limit(control)
    end
  end

  context 'with an invalid project_id' do
    let(:project_gid) { "gid://gitlab/Project/#{non_existing_record_id}" }

    it 'returns no configured AI catalog items' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'with a specified item_type' do
    let(:item_type) { :FLOW }
    let(:args) { { projectId: project_gid, item_type: item_type } }

    it 'returns only items of that type' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to match_array(configured_flows.map { |flow| a_graphql_entity_for(flow) })
    end
  end

  context 'when filtering by item_types' do
    let(:args) { { projectId: project_gid, item_types: %i[THIRD_PARTY_FLOW AGENT] } }

    it 'returns the matching items' do
      post_graphql(query, current_user: current_user)

      expect(nodes).to match_array(
        [*configured_agents, *configured_third_party_flows].map { |flow| a_graphql_entity_for(flow) }
      )
    end
  end

  context 'when filtering by item_type and item_types' do
    let(:args) { { projectId: project_gid, item_types: [:THIRD_PARTY_FLOW], item_type: :AGENT } }

    it 'returns items matching both arguments' do
      post_graphql(query, current_user: current_user)

      expect(nodes).to match_array(
        [*configured_agents, *configured_third_party_flows].map { |flow| a_graphql_entity_for(flow) }
      )
    end
  end

  context 'when filtering by group_id and configurable_for_project_id' do
    let_it_be(:group) { create(:group, guests: guest, developers: developer) }
    let_it_be(:configurable_for_project) do
      create(:project, :public, guests: guest, developers: developer, group: group)
    end

    let_it_be(:configurable_for_project_private_flow) do
      create(:ai_catalog_flow, :private, project: configurable_for_project)
    end

    let_it_be(:other_project_public_agent) do
      create(:ai_catalog_agent, :public, project: project)
    end

    let_it_be(:group_configured_items) do
      [
        create(:ai_catalog_item_consumer, group: group, item: catalog_flows[0]),
        create(:ai_catalog_item_consumer, group: group, item: catalog_agents[0]),
        create(:ai_catalog_item_consumer, group: group, item: catalog_third_party_flows[0]),
        create(:ai_catalog_item_consumer, group: group, item: configurable_for_project_private_flow),
        create(:ai_catalog_item_consumer, group: group, item: other_project_public_agent)
      ]
    end

    let(:args) do
      { groupId: group.to_global_id, configurableForProjectId: configurable_for_project.to_global_id }
    end

    it 'returns only items that are public or belong to the project' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to contain_exactly(
        a_graphql_entity_for(group_configured_items[3]),
        a_graphql_entity_for(group_configured_items[4])
      )
    end

    context 'when filtering by item_types' do
      let(:args) { super().merge(item_types: %i[AGENT]) }

      it 'returns the matching items' do
        post_graphql(query, current_user: current_user)

        expect(nodes).to contain_exactly(a_graphql_entity_for(group_configured_items[4]))
      end
    end
  end
end
