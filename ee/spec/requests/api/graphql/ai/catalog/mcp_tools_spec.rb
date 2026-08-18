# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog MCP tools', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let(:current_user) { create(:user) }
  let(:nodes) { graphql_data_at(:ai_catalog_mcp_tools, :nodes) }

  let(:query) do
    "{ #{query_nodes('AiCatalogMcpTools', max_depth: 2)} }"
  end

  it 'returns all MCP tools sorted by name' do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to have_attributes(size: ::Ai::Catalog::McpTool.all.size)
    expect(nodes.sort_by { |node| node['name'] }).to eq(nodes)

    first_node = nodes.first
    tool = ::Ai::Catalog::McpTool.find_by(name: first_node['name'])
    expect(first_node['name']).to eq(tool.name)
    expect(first_node['title']).to eq(tool.title)
    expect(first_node['description']).to eq(tool.description)
  end

  it 'returns icons for each MCP tool from the GitLab MCP server icon config' do
    post_graphql(query, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(nodes).to all(include('icons'))

    icons = nodes.first['icons']
    expect(icons).to be_an(Array).and(be_present)
    expect(icons.first.keys).to match_array(%w[src mimeType theme])
    expect(icons.first['src']).to include('gitlab_logo')
    expect(icons.size).to eq(::Mcp::Tools::Base::IconConfig.gitlab_icons.size)
    expect(icons.map { |icon| icon['theme'] }).to match_array(%w[dark light])
  end

  context 'when mcp_client feature flag is disabled' do
    before do
      stub_feature_flags(mcp_client: false)
    end

    it 'returns an empty list' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'when GitLab MCP server tools are not available for the user' do
    before do
      allow(::Ai::Catalog).to receive(:show_gitlab_mcp_server_tools?).with(current_user).and_return(false)
    end

    it 'returns an empty list' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end
end
