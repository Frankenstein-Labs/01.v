# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog MCP servers', :with_current_organization, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, organizations: [current_organization]) }
  let_it_be(:other_organization) { create(:organization) }

  let_it_be_with_reload(:mcp_server1) do
    create(:ai_catalog_mcp_server,
      organization: current_organization,
      name: 'MCP Server 1',
      url: 'https://example.com/mcp1',
      transport: :http,
      auth_type: :oauth
    )
  end

  let_it_be_with_reload(:mcp_server2) do
    create(:ai_catalog_mcp_server,
      organization: current_organization,
      name: 'MCP Server 2',
      url: 'https://example.com/mcp2',
      transport: :http,
      auth_type: :no_auth
    )
  end

  let_it_be(:mcp_server_from_other_org) do
    create(:ai_catalog_mcp_server,
      organization: other_organization,
      name: 'Other Org Server',
      url: 'https://other.com/mcp'
    )
  end

  let(:nodes) { graphql_data_at(:ai_catalog_mcp_servers, :nodes) }
  let(:current_user) { nil }
  let(:query) do
    "{ #{query_nodes('AiCatalogMcpServers', max_depth: 3)} }"
  end

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).and_return(true)
  end

  shared_examples 'a successful query' do
    it 'returns MCP servers from the current organization' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to match_array(
        expected_servers.map { |server| a_graphql_entity_for(server) }
      )
    end
  end

  shared_examples 'an unsuccessful query' do
    it 'returns no MCP servers' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).to be_empty
    end
  end

  context 'with valid setup' do
    let(:expected_servers) { [mcp_server1, mcp_server2] }
    let(:current_user) { user }

    it_behaves_like 'a successful query'

    it 'does not return servers from other organizations' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes).not_to include(a_graphql_entity_for(mcp_server_from_other_org))
    end

    context 'when AI Catalog is unavailable' do
      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).and_return(false)
      end

      it_behaves_like 'an unsuccessful query'
    end

    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it_behaves_like 'an unsuccessful query'
    end

    context 'when user is not a member of the organization' do
      let(:current_user) { create(:user, organizations: []) }

      it_behaves_like 'an unsuccessful query'
    end
  end

  context 'when querying specific fields' do
    let(:current_user) { user }
    let(:query) do
      <<~GRAPHQL
        {
          aiCatalogMcpServers {
            nodes {
              id
              name
              description
              url
              transport
              authType
              createdAt
              updatedAt
            }
          }
        }
      GRAPHQL
    end

    it 'returns all requested fields' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes.first).to include(
        'id' => mcp_server2.to_global_id.to_s,
        'name' => mcp_server2.name,
        'url' => mcp_server2.url,
        'transport' => 'HTTP',
        'authType' => 'NO_AUTH'
      )
    end
  end

  describe 'ordering' do
    let(:current_user) { user }

    it 'returns servers ordered by created_at descending' do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(nodes.pluck('id')).to eq([
        mcp_server2.to_global_id.to_s,
        mcp_server1.to_global_id.to_s
      ])
    end
  end

  describe 'blockStatus field' do
    let_it_be(:group) { create(:group, organization: current_organization) }
    let_it_be(:subgroup) { create(:group, parent: group, organization: current_organization) }
    let_it_be(:project) { create(:project, group: group) }

    let(:current_user) { user }

    before_all do
      group.add_guest(user)
      create(:ai_catalog_mcp_server_block,
        organization: current_organization, namespace: group, mcp_server: mcp_server1)
    end

    def block_status_query(args)
      "{ aiCatalogMcpServers { nodes { id blockStatus(#{args}) } } }"
    end

    def status_for(server)
      nodes.find { |node| node['id'] == server.to_global_id.to_s }['blockStatus']
    end

    it 'returns BLOCKED for a server blocked on the group and ACTIVE otherwise' do
      post_graphql(block_status_query(%(groupFullPath: "#{group.full_path}")), current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(status_for(mcp_server1)).to eq('BLOCKED')
      expect(status_for(mcp_server2)).to eq('ACTIVE')
    end

    it 'returns BLOCKED_BY_ANCESTOR when queried from a descendant group' do
      post_graphql(block_status_query(%(groupFullPath: "#{subgroup.full_path}")), current_user: current_user)

      expect(status_for(mcp_server1)).to eq('BLOCKED_BY_ANCESTOR')
    end

    it 'resolves projectFullPath, inheriting the ancestor group block' do
      post_graphql(block_status_query(%(projectFullPath: "#{project.full_path}")), current_user: current_user)

      expect(status_for(mcp_server1)).to eq('BLOCKED_BY_ANCESTOR')
    end

    it 'errors when both groupFullPath and projectFullPath are provided' do
      post_graphql(
        block_status_query(%(groupFullPath: "#{group.full_path}", projectFullPath: "#{project.full_path}")),
        current_user: current_user
      )

      expect(graphql_errors).to include(a_hash_including('message' => a_string_matching(/only one/)))
    end

    it 'errors when the group is not found or not accessible' do
      post_graphql(block_status_query(%(groupFullPath: "nope/does-not-exist")), current_user: current_user)

      expect(graphql_errors).to include(a_hash_including('message' => a_string_matching(/not found/)))
    end
  end
end
