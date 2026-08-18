# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AI Catalog Integration (GraphQL fixtures)', type: :request, feature_category: :workflow_catalog do
  include ApiHelpers
  include GraphqlHelpers
  include JavaScriptFixturesHelpers
  include Ai::Catalog::TestHelpers

  let_it_be(:user, freeze: false) { create(:user) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project, freeze: false) { create(:project, group: group) }

  let_it_be(:agent, freeze: false) { create(:ai_catalog_agent, :public, project: project) }
  let_it_be(:agent_v1, freeze: false) do
    create(:ai_catalog_agent_version, :released, item: agent, version: '1.0.0',
      definition: { 'system_prompt' => 'Pinned agent prompt', 'tools' => [], 'user_prompt' => '' })
  end

  let_it_be(:agent_v2, freeze: false) do
    create(:ai_catalog_agent_version, :released, item: agent, version: '2.0.0',
      definition: { 'system_prompt' => 'Latest agent prompt', 'tools' => [], 'user_prompt' => '' })
  end

  let_it_be(:agent_consumer, freeze: false) do
    create(:ai_catalog_item_consumer, :for_agent,
      item: agent, project: project, pinned_version_prefix: '1.0.0')
  end

  let_it_be(:agent_at_latest, freeze: false) { create(:ai_catalog_agent, :public, project: project) }
  let_it_be(:agent_at_latest_v1, freeze: false) do
    create(:ai_catalog_agent_version, :released, item: agent_at_latest, version: '1.0.0',
      definition: { 'system_prompt' => 'Pinned agent prompt', 'tools' => [], 'user_prompt' => '' })
  end

  let_it_be(:agent_at_latest_v2, freeze: false) do
    create(:ai_catalog_agent_version, :released, item: agent_at_latest, version: '2.0.0',
      definition: { 'system_prompt' => 'Latest agent prompt', 'tools' => [], 'user_prompt' => '' })
  end

  let_it_be(:agent_at_latest_consumer, freeze: false) do
    create(:ai_catalog_item_consumer, :for_agent,
      item: agent_at_latest, project: project, pinned_version_prefix: '2.0.0')
  end

  let_it_be(:flow, freeze: false) { create(:ai_catalog_flow, :public, project: project) }
  let_it_be(:flow_v1, freeze: false) do
    create(:ai_catalog_flow_version, :released, item: flow, version: '1.0.0')
  end

  let_it_be(:flow_v2, freeze: false) do
    create(:ai_catalog_flow_version, :released, item: flow, version: '2.0.0')
  end

  let_it_be(:flow_consumer, freeze: false) do
    create(:ai_catalog_item_consumer, :for_flow,
      item: flow, project: project, pinned_version_prefix: '1.0.0')
  end

  let_it_be(:flow_at_latest, freeze: false) { create(:ai_catalog_flow, :public, project: project) }
  let_it_be(:flow_at_latest_v1, freeze: false) do
    create(:ai_catalog_flow_version, :released, item: flow_at_latest, version: '1.0.0')
  end

  let_it_be(:flow_at_latest_v2, freeze: false) do
    create(:ai_catalog_flow_version, :released, item: flow_at_latest, version: '2.0.0')
  end

  let_it_be(:flow_at_latest_consumer, freeze: false) do
    create(:ai_catalog_item_consumer, :for_flow,
      item: flow_at_latest, project: project, pinned_version_prefix: '2.0.0')
  end

  base_output_path = 'graphql/ai_catalog/integration/'

  before_all do
    project.add_maintainer(user)
  end

  before do
    enable_ai_catalog
    stub_licensed_features(ai_catalog: true)
    sign_in(user)
  end

  shared_examples 'item query fixture' do |item_ref:, query_path:, output_name:|
    it "#{base_output_path}#{output_name}" do
      query = get_graphql_query_as_string(query_path, ee: true)
      post_graphql(query, current_user: user, variables: {
        id: send(item_ref).to_global_id.to_s,
        showSoftDeleted: false,
        projectId: project.to_global_id.to_s,
        hasProject: true,
        groupId: group.to_global_id.to_s,
        hasGroup: false
      })
      expect_graphql_errors_to_be_empty
    end
  end

  describe GraphQL::Query do
    include_examples 'item query fixture',
      item_ref: :agent,
      query_path: 'ai/catalog/graphql/queries/ai_catalog_agent.query.graphql',
      output_name: 'ai_catalog_agent.query.graphql.json'

    include_examples 'item query fixture',
      item_ref: :agent_at_latest,
      query_path: 'ai/catalog/graphql/queries/ai_catalog_agent.query.graphql',
      output_name: 'ai_catalog_agent_pinned_to_latest.query.graphql.json'

    include_examples 'item query fixture',
      item_ref: :flow,
      query_path: 'ai/catalog/graphql/queries/ai_catalog_flow.query.graphql',
      output_name: 'ai_catalog_flow.query.graphql.json'

    include_examples 'item query fixture',
      item_ref: :flow_at_latest,
      query_path: 'ai/catalog/graphql/queries/ai_catalog_flow.query.graphql',
      output_name: 'ai_catalog_flow_pinned_to_latest.query.graphql.json'

    it "#{base_output_path}ai_catalog_mcp_tools.query.graphql.json" do
      query = get_graphql_query_as_string(
        'ai/catalog/graphql/queries/ai_catalog_mcp_tools.query.graphql', ee: true
      )
      post_graphql(query, current_user: user)
      expect_graphql_errors_to_be_empty
    end

    it "#{base_output_path}ai_catalog_projects_maintainer.query.graphql.json" do
      query = get_graphql_query_as_string(
        'ai/catalog/graphql/queries/ai_catalog_projects_maintainer.query.graphql', ee: true
      )
      post_graphql(query, current_user: user)
      expect_graphql_errors_to_be_empty
    end
  end

  describe GraphQL::Query, 'mutations' do
    it "#{base_output_path}update_ai_catalog_item_consumer.mutation.graphql.json" do
      query = get_graphql_query_as_string(
        'ai/catalog/graphql/mutations/update_ai_catalog_item_consumer.mutation.graphql', ee: true
      )
      post_graphql(query, current_user: user, variables: {
        input: {
          id: agent_consumer.to_global_id.to_s,
          pinnedVersionPrefix: agent_v2.version
        }
      })
      expect_graphql_errors_to_be_empty
    end
  end
end
