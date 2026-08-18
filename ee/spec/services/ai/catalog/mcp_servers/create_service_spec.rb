# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::CreateService, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, owner_of: organization) }

  let(:params) do
    {
      name: 'Test MCP Server',
      description: 'A test MCP server',
      url: 'https://example.com/mcp',
      homepage_url: 'https://example.com',
      transport: :http,
      auth_type: :oauth,
      oauth_client_id: 'client-id-123',
      oauth_client_secret: { 'secret' => 'value' }
    }
  end

  subject(:response) do
    described_class.new(
      organization: organization,
      current_user: user,
      params: params
    ).execute
  end

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
    allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
  end

  describe '#execute' do
    context 'when organization is present' do
      it 'returns a success response with mcp_server in payload' do
        expect(response).to be_success
        expect(response.payload[:mcp_server]).to be_a(Ai::Catalog::McpServer)
      end

      it 'creates an MCP server with expected data' do
        expect { response }.to change { Ai::Catalog::McpServer.count }.by(1)

        mcp_server = Ai::Catalog::McpServer.last
        expect(mcp_server).to have_attributes(
          name: params[:name],
          description: params[:description],
          url: params[:url],
          homepage_url: params[:homepage_url],
          transport: 'http',
          auth_type: 'oauth',
          oauth_client_id: params[:oauth_client_id],
          organization: organization
        )
        expect(mcp_server.oauth_client_secret).to eq(params[:oauth_client_secret])
      end

      it 'creates an audit event', :aggregate_failures do
        expect { response }.to change { AuditEvents::InstanceAuditEvent.count }.by(1)

        mcp_server = Ai::Catalog::McpServer.last
        audit_event = AuditEvents::InstanceAuditEvent.last
        expect(audit_event).to have_attributes(
          author_id: user.id,
          target_details: "#{mcp_server.name} (ID: #{mcp_server.id})",
          target_type: 'Ai::Catalog::McpServer',
          event_name: 'create_ai_catalog_mcp_server'
        )
        expect(audit_event.details).to include(
          custom_message: "Created MCP server (URL: #{mcp_server.url})"
        )
      end
    end

    context 'when user does not have permission' do
      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
      end

      it 'returns an error response' do
        expect(response).to be_error
        expect(response.message).to include('Resource is unavailable')
      end

      it 'does not create an MCP server' do
        expect { response }.not_to change { Ai::Catalog::McpServer.count }
      end

      it 'does not create an audit event' do
        expect { response }.not_to change { AuditEvents::InstanceAuditEvent.count }
      end
    end

    context 'when organization is nil' do
      let(:organization) { nil }

      it 'returns an error response' do
        expect(response).to be_error
        expect(response.message).to include('Organization context is required')
      end

      it 'does not create an MCP server' do
        expect { response }.not_to change { Ai::Catalog::McpServer.count }
      end
    end

    context 'when validation fails' do
      let(:params) do
        {
          name: '',
          url: 'https://example.com/mcp',
          transport: :http,
          auth_type: :oauth
        }
      end

      it 'returns an error response with validation errors' do
        expect(response).to be_error
        expect(response.message).to include("Name can't be blank")
      end

      it 'does not create an MCP server' do
        expect { response }.not_to change { Ai::Catalog::McpServer.count }
      end
    end

    context 'when URL is invalid' do
      let(:params) do
        {
          name: 'Test Server',
          url: 'not-a-valid-url',
          transport: :http,
          auth_type: :oauth
        }
      end

      it 'returns an error response with URL validation error' do
        expect(response).to be_error
        expect(response.message.first).to include('is blocked')
      end

      it 'does not create an MCP server' do
        expect { response }.not_to change { Ai::Catalog::McpServer.count }
      end
    end
  end
end
