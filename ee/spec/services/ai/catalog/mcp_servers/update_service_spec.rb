# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::UpdateService, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, owner_of: organization) }
  let_it_be_with_reload(:mcp_server) { create(:ai_catalog_mcp_server, organization: organization) }

  let(:params) do
    {
      name: 'Updated MCP Server',
      description: 'An updated description',
      url: 'https://updated.example.com/mcp',
      homepage_url: 'https://updated.example.com',
      auth_type: :oauth,
      oauth_client_id: 'new-client-id'
    }
  end

  subject(:response) do
    described_class.new(
      organization: organization,
      current_user: user,
      mcp_server: mcp_server,
      params: params
    ).execute
  end

  before do
    allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
    allow(Gitlab::Audit::Auditor).to receive(:audit).and_call_original
  end

  describe '#execute' do
    context 'when organization is present and user has permission' do
      it 'returns a success response with mcp_server in payload' do
        expect(response).to be_success
        expect(response.payload[:mcp_server]).to eq(mcp_server)
      end

      it 'updates the MCP server with expected data' do
        response

        expect(mcp_server.reload).to have_attributes(
          name: params[:name],
          description: params[:description],
          url: params[:url],
          homepage_url: params[:homepage_url],
          auth_type: 'oauth',
          oauth_client_id: params[:oauth_client_id]
        )
      end

      it 'creates an audit event', :aggregate_failures do
        expect { response }.to change { AuditEvents::InstanceAuditEvent.count }.by(1)

        audit_event = AuditEvents::InstanceAuditEvent.last
        expect(audit_event).to have_attributes(
          author_id: user.id,
          target_details: "#{mcp_server.name} (ID: #{mcp_server.id})",
          target_type: 'Ai::Catalog::McpServer',
          event_name: 'update_ai_catalog_mcp_server'
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

      it 'does not update the MCP server' do
        response
        expect(mcp_server.reload.name).not_to eq(params[:name])
      end

      it 'does not create an audit event' do
        expect { response }.not_to change { AuditEvents::InstanceAuditEvent.count }
      end
    end

    context 'when organization is nil' do
      subject(:response) do
        described_class.new(
          organization: nil,
          current_user: user,
          mcp_server: mcp_server,
          params: params
        ).execute
      end

      it 'returns an error response' do
        expect(response).to be_error
        expect(response.message).to include('Organization context is required')
      end

      it 'does not update the MCP server' do
        response
        expect(mcp_server.reload.name).not_to eq(params[:name])
      end
    end

    context 'when validation fails' do
      let(:params) { { name: '', url: 'https://updated.example.com/mcp' } }

      it 'returns an error response with validation errors' do
        expect(response).to be_error
        expect(response.message).to include("Name can't be blank")
      end

      it 'does not persist the invalid name to the database' do
        response
        expect(mcp_server.reload.name).not_to be_empty
      end

      it 'does not create an audit event' do
        expect { response }.not_to change { AuditEvents::InstanceAuditEvent.count }
      end
    end

    context 'when URL is invalid' do
      let(:params) { { url: 'not-a-valid-url' } }

      it 'returns an error response with URL validation error' do
        expect(response).to be_error
        expect(response.message.first).to include('is blocked')
      end

      it 'does not persist the invalid URL to the database' do
        response
        expect(mcp_server.reload.url).not_to eq('not-a-valid-url')
      end
    end
  end
end
