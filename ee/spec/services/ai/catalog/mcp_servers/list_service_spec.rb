# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::ListService, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:mcp_server1) { create(:ai_catalog_mcp_server, organization: organization) }
  let_it_be(:mcp_server2) { create(:ai_catalog_mcp_server, organization: organization) }

  let_it_be(:agent_version) do
    create(:ai_catalog_agent_version, organization: organization, definition: {
      'system_prompt' => 'Test prompt',
      'tools' => [],
      'user_prompt' => '',
      'mcp_servers' => [mcp_server1.id, mcp_server2.id]
    })
  end

  subject(:result) { described_class.new(agent_version, user).execute }

  describe '#execute' do
    context 'when user has permission to read MCP servers' do
      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
      end

      it 'returns MCP servers for the given IDs' do
        expect(result).to contain_exactly(mcp_server1, mcp_server2)
      end
    end

    context 'when user does not have permission to read MCP servers' do
      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
      end

      it 'returns an empty relation' do
        expect(result).to be_empty
      end
    end

    context 'when mcp_servers is blank' do
      let_it_be(:agent_version_blank) do
        create(:ai_catalog_agent_version, definition: {
          'system_prompt' => 'Test prompt',
          'tools' => [],
          'user_prompt' => '',
          'mcp_servers' => []
        })
      end

      subject(:result) { described_class.new(agent_version_blank, user).execute }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
      end

      it 'returns an empty relation' do
        expect(result).to be_empty
      end
    end

    context 'when mcp_servers is nil' do
      let_it_be(:agent_version_nil) do
        create(:ai_catalog_agent_version, definition: {
          'system_prompt' => 'Test prompt',
          'tools' => [],
          'user_prompt' => ''
        })
      end

      subject(:result) { described_class.new(agent_version_nil, user).execute }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
      end

      it 'returns an empty relation' do
        expect(result).to be_empty
      end
    end

    context 'when a server is blocked (kill-switch)' do
      let_it_be(:group) { create(:group, organization: organization) }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
        create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server1, organization: organization)
      end

      it 'still lists blocked servers (enforcement is per tool call, not at listing)' do
        expect(described_class.new(agent_version, user).execute).to contain_exactly(mcp_server1, mcp_server2)
      end
    end

    context 'when some MCP server IDs do not exist' do
      let_it_be(:agent_version_nonexistent) do
        create(:ai_catalog_agent_version, organization: organization, definition: {
          'system_prompt' => 'Test prompt',
          'tools' => [],
          'user_prompt' => '',
          'mcp_servers' => [mcp_server1.id, non_existing_record_id]
        })
      end

      subject(:result) { described_class.new(agent_version_nonexistent, user).execute }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
      end

      it 'returns only existing MCP servers' do
        expect(result).to contain_exactly(mcp_server1)
      end
    end
  end
end
