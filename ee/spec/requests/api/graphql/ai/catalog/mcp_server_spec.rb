# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting an AI catalog MCP server', :with_current_organization, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, organizations: [current_organization]) }
  let_it_be_with_reload(:mcp_server) do
    create(:ai_catalog_mcp_server,
      organization: current_organization,
      name: 'Test MCP Server',
      description: 'A test MCP server',
      url: 'https://example.com/mcp',
      homepage_url: 'https://example.com',
      transport: :http,
      auth_type: :oauth,
      oauth_client_xid: 'client123'
    )
  end

  let(:data) { graphql_data_at(:ai_catalog_mcp_server) }
  let(:params) { { id: mcp_server.to_global_id } }
  let(:query_args) { attributes_to_graphql(params) }
  let(:current_user) { nil }

  let(:query) do
    <<~GRAPHQL
      query {
        aiCatalogMcpServer(#{query_args}) {
          id
          name
          description
          url
          homepageUrl
          transport
          authType
          oauthClientId
          createdAt
          updatedAt
          organization {
            id
          }
        }
      }
    GRAPHQL
  end

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).and_return(true)
  end

  shared_examples 'a successful query' do
    it 'returns the MCP server' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to match(
        hash_including(
          'id' => mcp_server.to_global_id.to_s,
          'name' => mcp_server.name,
          'description' => mcp_server.description,
          'url' => mcp_server.url,
          'homepageUrl' => mcp_server.homepage_url,
          'transport' => 'HTTP',
          'authType' => 'OAUTH',
          'oauthClientId' => mcp_server.oauth_client_id,
          'createdAt' => mcp_server.created_at.iso8601,
          'updatedAt' => mcp_server.updated_at.iso8601,
          'organization' => a_graphql_entity_for(current_organization)
        )
      )
    end
  end

  shared_examples 'an unsuccessful query' do
    it 'returns nil' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(data).to be_nil
    end
  end

  context 'with valid MCP server' do
    context 'when user is authenticated' do
      let(:current_user) { user }

      it_behaves_like 'a successful query'
    end

    context 'when AI Catalog is unavailable' do
      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).and_return(false)
      end

      it_behaves_like 'an unsuccessful query'
    end

    context 'when the MCP server does not exist' do
      let(:params) { { id: global_id_of(id: non_existing_record_id, model_name: 'Ai::Catalog::McpServer') } }

      it_behaves_like 'an unsuccessful query'
    end
  end

  context 'when MCP server belongs to another organization' do
    let_it_be(:other_organization) { create(:organization) }
    let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, organization: other_organization) }

    it_behaves_like 'an unsuccessful query'
  end
end
