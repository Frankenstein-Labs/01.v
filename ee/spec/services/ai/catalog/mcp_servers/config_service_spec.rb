# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::ConfigService, feature_category: :duo_agent_platform do
  let_it_be(:organization, freeze: false) { create(:organization) }
  let_it_be_with_refind(:user) { create(:user, organizations: [organization]) }
  let_it_be(:item, freeze: false) { create(:ai_catalog_item, :agent, :public, organization: organization) }

  let_it_be(:mcp_server, freeze: false) do
    create(
      :ai_catalog_mcp_server,
      organization: organization,
      name: 'Test MCP Server',
      url: 'https://mcp.example.com',
      auth_type: :oauth
    )
  end

  let_it_be(:mcp_servers_user, freeze: false) do
    create(
      :ai_catalog_mcp_servers_user,
      mcp_server: mcp_server,
      user: user,
      organization: organization,
      token: 'user_mcp_token_123'
    )
  end

  let_it_be(:item_version, freeze: false) do
    create(
      :ai_catalog_item_version,
      item: item,
      organization: organization,
      definition: {
        system_prompt: 'Test prompt',
        tools: [],
        mcp_servers: [mcp_server.id]
      }
    )
  end

  subject(:service) { described_class.new(item_version, user) }

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
  end

  describe '#execute' do
    it 'returns a hash keyed by normalized server name' do
      result = service.execute

      expect(result).to have_key(:test_mcp_server)
    end

    it 'includes the server URL' do
      result = service.execute

      expect(result[:test_mcp_server][:URL]).to eq('https://mcp.example.com')
    end

    it 'includes OAuth authorization header when user has a token' do
      result = service.execute

      expect(result[:test_mcp_server][:Headers]).to eq(Authorization: 'Bearer user_mcp_token_123')
    end

    context 'when the token is expired' do
      let(:refresh_service) { instance_double(Ai::Catalog::McpServers::RefreshTokenService) }

      it 'calls RefreshTokenService' do
        mcp_servers_user.update!(token: 'old_token', expires_at: 1.hour.ago)

        expect_next_instance_of(Ai::Catalog::McpServers::RefreshTokenService) do |service|
          expect(service).to receive(:execute).and_return(ServiceResponse.success)
        end

        service.execute
      end
    end

    context 'when the token expires within the clock skew window (under 2 minutes)' do
      it 'calls RefreshTokenService to preemptively refresh' do
        mcp_servers_user.update!(expires_at: 90.seconds.from_now)

        expect_next_instance_of(Ai::Catalog::McpServers::RefreshTokenService) do |svc|
          expect(svc).to receive(:execute).and_return(ServiceResponse.success)
        end

        service.execute
      end
    end

    context 'when the token is not expired' do
      it 'does not call RefreshTokenService' do
        mcp_servers_user.update!(expires_at: 3.minutes.from_now)

        expect(Ai::Catalog::McpServers::RefreshTokenService).not_to receive(:new)

        service.execute
      end
    end

    context 'when expires_at is nil' do
      before do
        mcp_servers_user.update!(expires_at: nil)
      end

      it 'does not call RefreshTokenService' do
        expect(Ai::Catalog::McpServers::RefreshTokenService).not_to receive(:new)

        service.execute
      end

      it 'uses the existing token' do
        result = service.execute

        expect(result[:test_mcp_server][:Headers]).to eq(Authorization: 'Bearer user_mcp_token_123')
      end
    end

    context 'when MCP server has no_auth type' do
      let_it_be(:no_auth_server) do
        create(
          :ai_catalog_mcp_server,
          organization: organization,
          name: 'No Auth Server',
          url: 'https://noauth.example.com',
          auth_type: :no_auth
        )
      end

      let_it_be(:no_auth_servers_user) do
        create(
          :ai_catalog_mcp_servers_user,
          mcp_server: no_auth_server,
          user: user,
          organization: organization
        )
      end

      let_it_be(:item_version_with_no_auth) do
        create(
          :ai_catalog_item_version,
          item: item,
          organization: organization,
          definition: {
            system_prompt: 'Test prompt',
            tools: [],
            mcp_servers: [no_auth_server.id]
          }
        )
      end

      subject(:service) { described_class.new(item_version_with_no_auth, user) }

      it 'includes the server with empty headers' do
        result = service.execute

        expect(result[:no_auth_server]).to match(
          URL: 'https://noauth.example.com',
          Headers: {}
        )
      end
    end

    context 'when user has no McpServersUser association for the server' do
      let_it_be(:server_without_user) do
        create(
          :ai_catalog_mcp_server,
          organization: organization,
          name: 'Server Without User',
          url: 'https://noaccess.example.com',
          auth_type: :oauth
        )
      end

      let_it_be(:item_version_without_user) do
        create(
          :ai_catalog_item_version,
          item: item,
          organization: organization,
          definition: {
            system_prompt: 'Test prompt',
            tools: [],
            mcp_servers: [server_without_user.id]
          }
        )
      end

      subject(:service) { described_class.new(item_version_without_user, user) }

      it 'includes the server with empty headers' do
        result = service.execute

        expect(result[:server_without_user]).to match(
          URL: 'https://noaccess.example.com',
          Headers: {}
        )
      end
    end

    context 'when the item version has no mcp_servers in its definition' do
      let_it_be(:item_version_no_servers) do
        create(
          :ai_catalog_item_version,
          item: item,
          organization: organization,
          definition: {
            system_prompt: 'Test prompt',
            tools: []
          }
        )
      end

      subject(:service) { described_class.new(item_version_no_servers, user) }

      it 'returns an empty hash' do
        expect(service.execute).to eq({})
      end
    end

    context 'when mcp servers are not available for the user' do
      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
      end

      it 'returns an empty hash' do
        expect(service.execute).to eq({})
      end
    end

    context 'when current_user is nil' do
      subject(:service) { described_class.new(item_version, nil) }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(nil).and_return(false)
      end

      it 'returns an empty hash' do
        expect(service.execute).to eq({})
      end
    end

    context 'when server name contains special characters' do
      let_it_be(:special_name_server) do
        create(
          :ai_catalog_mcp_server,
          organization: organization,
          name: 'My MCP-Server 2.0!',
          url: 'https://special.example.com',
          auth_type: :no_auth
        )
      end

      let_it_be(:item_version_special) do
        create(
          :ai_catalog_item_version,
          item: item,
          organization: organization,
          definition: {
            system_prompt: 'Test prompt',
            tools: [],
            mcp_servers: [special_name_server.id]
          }
        )
      end

      subject(:service) { described_class.new(item_version_special, user) }

      it 'normalizes the server name to a symbol key' do
        result = service.execute

        expect(result).to have_key(:my_mcp_server_2_0_)
      end
    end
  end
end
