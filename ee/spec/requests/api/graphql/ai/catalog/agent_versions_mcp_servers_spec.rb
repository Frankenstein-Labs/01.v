# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'GraphQL aiCatalogItem.versions (AiCatalogAgentVersion.mcpServers)', :with_current_organization, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project, organization: current_organization) }

  let_it_be_with_reload(:linear_mcp_server) do
    create(:ai_catalog_mcp_server,
      organization: current_organization,
      name: 'Linear MCP Server',
      description: 'Interact with Linear issues and projects (doc-style example).',
      url: 'https://mcp.linear.app/mcp')
  end

  let_it_be(:atlassian_mcp_server) do
    create(:ai_catalog_mcp_server,
      organization: current_organization,
      name: 'Atlassian MCP Server',
      description: 'Interact with Jira and Confluence data (doc-style example).',
      url: 'https://mcp.atlassian.com/v1/mcp')
  end

  let_it_be_with_reload(:catalog_item) { create(:ai_catalog_item, :public, project: project) }

  let_it_be_with_reload(:first_agent_version) do
    create(:ai_catalog_item_version,
      item: catalog_item,
      version: '1.0.0',
      definition: { 'system_prompt' => '', 'tools' => [], 'user_prompt' => '',
                    'mcp_servers' => [linear_mcp_server.id] })
  end

  let_it_be(:second_agent_version) do
    create(:ai_catalog_item_version,
      item: catalog_item,
      version: '2.0.0',
      definition: {
        'system_prompt' => '', 'tools' => [], 'user_prompt' => '',
        'mcp_servers' => [atlassian_mcp_server.id]
      })
  end

  let(:current_user) { create(:user, organizations: [current_organization]) }

  let(:query) do
    <<~GRAPHQL
      query {
        aiCatalogItem(id: "#{catalog_item.to_global_id}") {
          versions {
            nodes {
              ... on AiCatalogAgentVersion {
                id
                mcpServers {
                  nodes {
                    id
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  before do
    enable_ai_catalog
    stub_application_setting(instance_level_ai_beta_features_enabled: true)
  end

  it 'batch-loads MCP servers per agent version without N+1 SELECTs on ai_catalog_mcp_servers' do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)

    version_nodes = graphql_data_at(:ai_catalog_item, :versions, :nodes)
    first_version_node = version_nodes.find { |node| node['id'] == first_agent_version.to_global_id.to_s }
    second_version_node = version_nodes.find { |node| node['id'] == second_agent_version.to_global_id.to_s }

    expect(first_version_node['mcpServers']['nodes']).to match_array([a_graphql_entity_for(linear_mcp_server)])
    expect(second_version_node['mcpServers']['nodes']).to match_array([a_graphql_entity_for(atlassian_mcp_server)])

    recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) do
      post_graphql(query, current_user: current_user)
    end

    # Fetch MCP server rows in one grouped trip through batch loading & not one trip for every version
    mcp_table_selects = recorder.log.count do |sql|
      sql.include?('"ai_catalog_mcp_servers"') && sql.match?(/\bSELECT\b/i)
    end
    expect(mcp_table_selects).to eq(1)
  end
end
