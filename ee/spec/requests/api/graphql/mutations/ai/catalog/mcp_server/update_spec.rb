# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::McpServer::Update, :with_current_organization,
  feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, owner_of: current_organization) }
  let_it_be_with_reload(:mcp_server) { create(:ai_catalog_mcp_server, organization: current_organization) }

  let(:current_user) { user }
  let(:mutation) do
    graphql_mutation(:ai_catalog_mcp_server_update, params) do
      <<~FIELDS
        errors
        mcpServer {
          id
          name
          description
          url
          homepageUrl
          transport
          authType
          oauthClientId
        }
      FIELDS
    end
  end

  let(:new_name) { 'Updated MCP Server' }
  let(:new_description) { 'An updated description' }
  let(:new_url) { 'https://updated.example.com/mcp' }
  let(:new_homepage_url) { 'https://updated.example.com' }
  let(:new_auth_type) { 'OAUTH' }
  let(:new_oauth_client_id) { 'new-client-id' }

  let(:params) do
    {
      id: mcp_server.to_global_id.to_s,
      name: new_name,
      description: new_description,
      url: new_url,
      homepage_url: new_homepage_url,
      auth_type: new_auth_type,
      oauth_client_id: new_oauth_client_id
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).and_return(true)
  end

  shared_examples 'an authorization failure' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not update the MCP server' do
      execute
      expect(mcp_server.reload.name).not_to eq(new_name)
    end
  end

  context 'when MCP servers are not available' do
    before do
      allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when user is not an org owner or admin' do
    let_it_be(:other_user) { create(:user, organizations: [current_organization]) }
    let(:current_user) { other_user }

    it_behaves_like 'an authorization failure'
  end

  context 'when model params are invalid' do
    let(:new_name) { '' }

    it 'returns validation errors' do
      execute

      expect(graphql_data_at(:ai_catalog_mcp_server_update, :errors)).to include(
        match(/Name can't be blank/)
      )
      expect(graphql_data_at(:ai_catalog_mcp_server_update, :mcp_server)).to be_nil
    end
  end

  it 'updates the MCP server with expected data' do
    execute

    expect(mcp_server.reload).to have_attributes(
      name: new_name,
      description: new_description,
      url: new_url,
      homepage_url: new_homepage_url,
      auth_type: 'oauth',
      oauth_client_id: new_oauth_client_id
    )
  end

  it 'returns the updated MCP server' do
    execute

    expect(graphql_data_at(:ai_catalog_mcp_server_update, :errors)).to be_empty
    expect(graphql_data_at(:ai_catalog_mcp_server_update, :mcp_server)).to match a_hash_including(
      'name' => new_name,
      'description' => new_description,
      'url' => new_url,
      'homepageUrl' => new_homepage_url,
      'authType' => 'OAUTH',
      'oauthClientId' => new_oauth_client_id
    )
  end

  context 'with partial update (only name)' do
    let(:params) do
      {
        id: mcp_server.to_global_id.to_s,
        name: new_name
      }
    end

    it 'updates only the provided fields' do
      original_url = mcp_server.url
      execute

      expect(mcp_server.reload).to have_attributes(
        name: new_name,
        url: original_url
      )
    end
  end
end
