# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting available AI catalog flows for a project', feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:guest) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:project) { create(:project, group: subgroup, guests: guest, maintainers: maintainer) }
  let_it_be(:catalog_flow) { create(:ai_catalog_flow) }
  let_it_be(:catalog_agent) { create(:ai_catalog_agent) }
  let_it_be(:flow_consumer) { create(:ai_catalog_item_consumer, group: root_group, item: catalog_flow) }
  let_it_be(:agent_consumer) { create(:ai_catalog_item_consumer, group: root_group, item: catalog_agent) }

  let(:current_user) { maintainer }
  let(:project_gid) { project.to_global_id }
  let(:nodes) { graphql_data_at(:ai_catalog_available_flows_for_project, :nodes) }
  let(:args) { { projectId: project_gid } }
  let(:fields) do
    <<~FIELDS
      nodes {
        id
        item {
          id
          name
          itemType
          ... on AiCatalogFlow {
            foundational
          }
        }
      }
    FIELDS
  end

  let(:query) do
    graphql_query_for('aiCatalogAvailableFlowsForProject', args, fields)
  end

  before_all do
    subgroup.add_maintainer(maintainer)
  end

  before do
    enable_ai_catalog
  end

  describe 'authorization' do
    context 'when user is a guest' do
      let(:current_user) { guest }

      it 'returns an error' do
        post_graphql(query, current_user: current_user)

        expect(graphql_errors).to include(
          a_hash_including('message' => a_string_matching(/you don't have permission/i))
        )
      end
    end

    context 'when user is a maintainer of the project' do
      it 'returns available flows' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(nodes).to contain_exactly(a_graphql_entity_for(flow_consumer))
      end
    end

    context 'when user is a subgroup owner without direct root group membership' do
      let_it_be(:subgroup_owner) { create(:user) }
      let(:current_user) { subgroup_owner }

      before_all do
        subgroup.add_owner(subgroup_owner)
      end

      it 'returns available flows via project membership' do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect(nodes).to contain_exactly(a_graphql_entity_for(flow_consumer))
      end
    end
  end

  describe 'filtering' do
    it 'returns only flow items, not agents' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to contain_exactly(a_graphql_entity_for(flow_consumer))
      expect(nodes).not_to include(a_graphql_entity_for(agent_consumer))
    end
  end
end
