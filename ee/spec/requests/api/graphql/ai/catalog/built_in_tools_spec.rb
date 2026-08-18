# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog built-in tools', feature_category: :workflow_catalog do
  include GraphqlHelpers

  let(:nodes) { graphql_data_at(:ai_catalog_built_in_tools, :nodes) }

  let(:query) do
    "{ #{query_nodes('AiCatalogBuiltInTools')} }"
  end

  it 'returns all built-in tools sorted by name, excluding get_previous_session_context', :aggregate_failures do
    post_graphql(query, current_user: nil)

    expect(response).to have_gitlab_http_status(:success)
    # Tool 58 (get_previous_session_context) is always excluded; see ai_catalog_built_in_tools.
    expect(nodes).to have_attributes(size: ::Ai::Catalog::BuiltInTool.count - 1)
    expect(nodes.sort_by { |node| node['name'] }).to eq(nodes)

    tool_names = nodes.pluck('name')
    expect(tool_names).not_to include('get_previous_session_context')

    first_node = nodes.first
    tool = ::Ai::Catalog::BuiltInTool.find_by(name: first_node['name'])
    expect(first_node).to match(a_graphql_entity_for(tool, :name, :title, :description))
  end

  context 'when use_generic_gitlab_api_tools is disabled' do
    before do
      stub_feature_flags(use_generic_gitlab_api_tools: false)
    end

    it 'returns built-in tools excluding generic GitLab API tools', :aggregate_failures do
      post_graphql(query, current_user: nil)

      expect(response).to have_gitlab_http_status(:success)
      # Should exclude tools with IDs 78 (gitlab_api_get), 79 (gitlab_graphql),
      # and 58 (get_previous_session_context, always excluded).
      expect(nodes).to have_attributes(size: ::Ai::Catalog::BuiltInTool.count - 3)

      tool_names = nodes.pluck('name')
      expect(tool_names).not_to include('gitlab_api_get', 'gitlab_graphql', 'get_previous_session_context')
    end
  end
end
