# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::McpServer::Create, :with_current_organization,
  feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:user) { create(:user, owner_of: current_organization) }

  let(:current_user) { user }
  let(:mutation) do
    graphql_mutation(:ai_catalog_mcp_server_create, params) do
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
          organization {
            id
          }
        }
      FIELDS
    end
  end

  let(:name) { 'Test MCP Server' }
  let(:description) { 'A test MCP server for development' }
  let(:url) { 'https://example.com/mcp' }
  let(:homepage_url) { 'https://example.com' }
  let(:transport) { 'HTTP' }
  let(:auth_type) { 'OAUTH' }
  let(:oauth_client_id) { 'test_client_id' }
  let(:oauth_client_secret) { 'test_secret' }

  let(:params) do
    {
      name: name,
      description: description,
      url: url,
      homepage_url: homepage_url,
      transport: transport,
      auth_type: auth_type,
      oauth_client_id: oauth_client_id,
      oauth_client_secret: oauth_client_secret
    }
  end

  subject(:execute) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
  end

  shared_examples 'an authorization failure' do
    it 'returns an error in response data' do
      execute

      expect(graphql_data_at(:ai_catalog_mcp_server_create, :errors)).to contain_exactly(
        'Resource is unavailable'
      )
      expect(graphql_data_at(:ai_catalog_mcp_server_create, :mcp_server)).to be_nil
    end

    it 'does not create an MCP server' do
      expect { execute }.not_to change { Ai::Catalog::McpServer.count }
    end
  end

  context 'when MCP servers are not available' do
    before do
      allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
    end

    it_behaves_like 'an authorization failure'
  end

  context 'when organization context is missing' do
    before do
      allow(Current).to receive(:organization).and_return(nil)
    end

    it 'returns an error' do
      execute

      expect(graphql_data_at(:ai_catalog_mcp_server_create, :errors)).to contain_exactly(
        'Organization context is required'
      )
      expect(graphql_data_at(:ai_catalog_mcp_server_create, :mcp_server)).to be_nil
    end
  end

  context 'when graphql params are invalid' do
    let(:name) { nil }
    let(:url) { nil }

    it 'returns the validation error' do
      execute

      expect(graphql_errors.first['message']).to include(
        'provided invalid value for',
        'name (Expected value to not be null)',
        'url (Expected value to not be null)'
      )
    end
  end

  context 'when model params are invalid' do
    let(:name) { '' }
    let(:url) { 'invalid-url' }

    it 'returns the validation error' do
      execute

      expect(graphql_data_at(:ai_catalog_mcp_server_create, :errors)).to include(
        match(/Name can't be blank/)
      )
      expect(graphql_data_at(:ai_catalog_mcp_server_create, :mcp_server)).to be_nil
    end
  end

  context 'when URL is not unique' do
    let_it_be(:existing_server) do
      create(:ai_catalog_mcp_server, organization: current_organization, url: 'https://example.com/mcp')
    end

    it 'returns a validation error' do
      execute

      expect(graphql_data_at(:ai_catalog_mcp_server_create, :errors)).to include(
        match(/Url has already been taken/)
      )
      expect(graphql_data_at(:ai_catalog_mcp_server_create, :mcp_server)).to be_nil
    end
  end

  it 'creates an MCP server with expected data' do
    expect { execute }.to change { Ai::Catalog::McpServer.count }.by(1)

    mcp_server = Ai::Catalog::McpServer.last

    expect(mcp_server).to have_attributes(
      name: name,
      description: description,
      url: url,
      homepage_url: homepage_url,
      transport: 'http',
      auth_type: 'oauth',
      oauth_client_id: oauth_client_id,
      organization: current_organization
    )
  end

  it 'returns the new MCP server' do
    execute

    expect(graphql_data_at(:ai_catalog_mcp_server_create, :errors)).to be_empty
    expect(graphql_data_at(:ai_catalog_mcp_server_create, :mcp_server)).to match a_hash_including(
      'name' => name,
      'description' => description,
      'url' => url,
      'homepageUrl' => homepage_url,
      'transport' => 'HTTP',
      'authType' => 'OAUTH',
      'oauthClientId' => oauth_client_id,
      'organization' => a_graphql_entity_for(current_organization)
    )
  end

  context 'with minimal required fields' do
    let(:params) do
      {
        name: name,
        url: url,
        transport: transport,
        auth_type: 'NO_AUTH'
      }
    end

    it 'creates an MCP server successfully' do
      expect { execute }.to change { Ai::Catalog::McpServer.count }.by(1)

      mcp_server = Ai::Catalog::McpServer.last

      expect(mcp_server).to have_attributes(
        name: name,
        url: url,
        description: nil,
        homepage_url: nil,
        transport: 'http',
        auth_type: 'no_auth',
        oauth_client_id: nil
      )
    end
  end
end
