# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::AuditEventMessageService, feature_category: :workflow_catalog do
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server) }

  let(:params) { {} }
  let(:service) { described_class.new(event_type, mcp_server, params) }

  describe '#messages' do
    subject(:messages) { service.messages }

    context 'when event_type is create_ai_catalog_mcp_server' do
      let(:event_type) { 'create_ai_catalog_mcp_server' }

      it 'returns a create message with URL' do
        expect(messages).to contain_exactly(
          "Created MCP server (URL: #{mcp_server.url})"
        )
      end
    end

    context 'when event_type is update_ai_catalog_mcp_server' do
      let_it_be_with_reload(:update_mcp_server) { create(:ai_catalog_mcp_server, name: 'Old Name') }

      let(:event_type) { 'update_ai_catalog_mcp_server' }
      let(:mcp_server) { update_mcp_server }

      context 'when name changes' do
        before do
          update_mcp_server.update!(name: 'New Name')
        end

        it 'returns an update message describing the name change' do
          expect(messages).to contain_exactly(
            "Updated MCP server: Name changed to 'New Name'"
          )
        end
      end

      context 'when URL changes' do
        before do
          update_mcp_server.update!(url: 'https://new.example.com/mcp')
        end

        it 'returns an update message describing the URL change' do
          expect(messages).to contain_exactly(
            "Updated MCP server: URL changed to 'https://new.example.com/mcp'"
          )
        end
      end

      context 'when description changes' do
        before do
          update_mcp_server.update!(description: 'New description')
        end

        it 'returns an update message noting the description update' do
          expect(messages).to contain_exactly(
            "Updated MCP server: Description updated"
          )
        end
      end

      context 'when transport changes' do
        before do
          allow(update_mcp_server).to receive(:previous_changes).and_return({ 'transport' => [0, 1] })
        end

        it 'returns an update message describing the transport change' do
          expect(messages).to contain_exactly(
            "Updated MCP server: Transport changed to '#{update_mcp_server.transport}'"
          )
        end
      end

      context 'when auth_type changes' do
        before do
          update_mcp_server.update!(auth_type: :oauth)
        end

        it 'returns an update message describing the auth type change' do
          expect(messages).to contain_exactly(
            "Updated MCP server: Auth type changed to 'oauth'"
          )
        end
      end

      context 'when multiple attributes change' do
        before do
          update_mcp_server.update!(name: 'New Name', description: 'New description')
        end

        it 'returns a single update message with all changes combined' do
          expect(messages).to contain_exactly(
            "Updated MCP server: Name changed to 'New Name', Description updated"
          )
        end
      end

      context 'when no tracked attributes change' do
        it 'returns a generic update message' do
          expect(messages).to contain_exactly(
            "Updated MCP server"
          )
        end
      end
    end

    context 'when event_type is unknown' do
      let(:event_type) { 'unknown_event' }

      it { is_expected.to eq([]) }
    end
  end
end
