# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServersBatchLoader, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: []) }
  let_it_be(:item, freeze: false) { create(:ai_catalog_agent, organization: organization) }
  let_it_be(:organization_user) { create(:organization_user, user: user, organization: organization) }
  let_it_be(:mcp_server1, freeze: false) { create(:ai_catalog_mcp_server, organization: organization) }
  let_it_be(:mcp_server2, freeze: false) { create(:ai_catalog_mcp_server, organization: organization) }

  let_it_be(:agent_version, freeze: false) do
    create(:ai_catalog_agent_version, item: item, definition: {
      'system_prompt' => 'Test prompt',
      'tools' => [],
      'user_prompt' => '',
      'mcp_servers' => [mcp_server1.id, mcp_server2.id]
    })
  end

  let_it_be(:second_agent_version) do
    create(:ai_catalog_item_version,
      item: item,
      version: '2.0.0',
      definition: {
        'system_prompt' => 'Test prompt',
        'tools' => [],
        'user_prompt' => '',
        'mcp_servers' => [mcp_server2.id]
      })
  end

  describe '.load_for' do
    before do
      allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
    end

    it 'batch-loads MCP servers for multiple agent versions together' do
      first_result, second_result = batch_sync do
        [
          described_class.load_for(agent_version, user),
          described_class.load_for(second_agent_version, user)
        ]
      end

      expect(first_result).to contain_exactly(mcp_server1, mcp_server2)
      expect(second_result).to contain_exactly(mcp_server2)
    end
  end

  describe '.batch_mcp_servers_for_item_versions' do
    context 'when no item version ids are given' do
      it 'returns an empty hash' do
        expect(described_class.batch_mcp_servers_for_item_versions([], user)).to eq({})
      end
    end

    context 'when all given item version ids do not exist in the database' do
      it 'returns each requested id mapped to an empty array' do
        result = described_class.batch_mcp_servers_for_item_versions([non_existing_record_id], user)

        expect(result).to eq(non_existing_record_id => [])
      end
    end

    context 'when batching multiple item versions with different mcp_servers' do
      let_it_be(:linear_mcp_server) do
        create(:ai_catalog_mcp_server, :with_oauth,
          organization: organization,
          name: 'Linear MCP Server',
          description: 'Interact with Linear issues and projects.',
          url: 'https://mcp.linear.app/mcp')
      end

      let_it_be(:atlassian_mcp_server) do
        create(:ai_catalog_mcp_server, :with_oauth,
          organization: organization,
          name: 'Atlassian MCP Server',
          description: 'Interact with Jira and Confluence data.',
          url: 'https://mcp.atlassian.com/v1/mcp')
      end

      let_it_be(:context7_mcp_server) do
        create(:ai_catalog_mcp_server,
          organization: organization,
          name: 'Context7 MCP Server',
          description: 'Documentation-oriented MCP server (example third entry).',
          url: 'https://context7.com/mcp')
      end

      let_it_be(:item_version_one) do
        create(:ai_catalog_item_version,
          item: item,
          version: '3.0.0',
          definition: {
            'system_prompt' => 'Test prompt',
            'tools' => [],
            'user_prompt' => '',
            'mcp_servers' => [linear_mcp_server.id, atlassian_mcp_server.id]
          })
      end

      let_it_be(:item_version_two) do
        create(:ai_catalog_item_version,
          item: item,
          version: '4.0.0',
          schema_version: 1,
          definition: {
            'system_prompt' => 'Test prompt',
            'tools' => [],
            'user_prompt' => '',
            'mcp_servers' => [atlassian_mcp_server.id, context7_mcp_server.id]
          })
      end

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
      end

      it 'returns each item version id mapped to only its own MCP servers without mixing across versions' do
        result = described_class.batch_mcp_servers_for_item_versions(
          [item_version_one.id, item_version_two.id], user)

        expect(result).to eq(
          item_version_one.id => [linear_mcp_server, atlassian_mcp_server],
          item_version_two.id => [atlassian_mcp_server, context7_mcp_server]
        )
      end
    end

    context 'when item versions belong to different organizations and MCP read is only allowed for one org' do
      let_it_be(:allowed_organization) { create(:organization) }
      let_it_be(:not_allowed_organization) { create(:organization) }
      let_it_be(:user_with_allowed_org_access) { create(:user, organizations: []) }
      let_it_be(:allowed_organization_membership) do
        create(:organization_user, user: user_with_allowed_org_access, organization: allowed_organization)
      end

      let_it_be(:allowed_mcp_server) do
        create(:ai_catalog_mcp_server, :with_oauth,
          organization: allowed_organization,
          name: 'Linear MCP Server',
          url: 'https://mcp.linear.app/mcp')
      end

      let_it_be(:not_allowed_mcp_server) do
        create(:ai_catalog_mcp_server, :with_oauth,
          organization: not_allowed_organization,
          name: 'Atlassian MCP Server',
          url: 'https://mcp.atlassian.com/v1/mcp')
      end

      let_it_be(:allowed_item, freeze: false) { create(:ai_catalog_agent, organization: allowed_organization) }
      let_it_be(:not_allowed_item, freeze: false) { create(:ai_catalog_agent, organization: not_allowed_organization) }

      let_it_be(:allowed_version, freeze: false) do
        create(:ai_catalog_agent_version,
          item: allowed_item,
          version: '5.0.0',
          schema_version: 1,
          definition: {
            'system_prompt' => 'Test prompt',
            'tools' => [],
            'user_prompt' => '',
            'mcp_servers' => [allowed_mcp_server.id]
          })
      end

      let_it_be(:not_allowed_version, freeze: false) do
        create(:ai_catalog_agent_version,
          item: not_allowed_item,
          version: '5.0.0',
          schema_version: 1,
          definition: {
            'system_prompt' => 'Test prompt',
            'tools' => [],
            'user_prompt' => '',
            'mcp_servers' => [not_allowed_mcp_server.id]
          })
      end

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user_with_allowed_org_access).and_return(true)
      end

      it 'returns MCP servers only for versions in organizations the user may read; other versions get empty arrays' do
        result = described_class.batch_mcp_servers_for_item_versions(
          [allowed_version.id, not_allowed_version.id], user_with_allowed_org_access)

        expect(result).to eq(
          allowed_version.id => [allowed_mcp_server],
          not_allowed_version.id => []
        )
      end

      context 'when current_user has :admin_all_resources' do
        before do
          allow(Ability).to receive(:allowed?).with(user_with_allowed_org_access, :admin_all_resources).and_return(true)
        end

        it 'returns MCP servers for every requested organization' do
          result = described_class.batch_mcp_servers_for_item_versions(
            [allowed_version.id, not_allowed_version.id], user_with_allowed_org_access)

          expect(result).to eq(
            allowed_version.id => [allowed_mcp_server],
            not_allowed_version.id => [not_allowed_mcp_server]
          )
        end
      end
    end

    context 'when the user cannot read AI catalog MCP servers for the organization' do
      let_it_be(:user_without_org_access) { create(:user, organizations: []) }

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user_without_org_access).and_return(true)
      end

      it 'returns empty arrays for every requested version id' do
        results = described_class.batch_mcp_servers_for_item_versions(
          [agent_version.id, second_agent_version.id], user_without_org_access)

        expect(results[agent_version.id]).to eq([])
        expect(results[second_agent_version.id]).to eq([])
      end
    end

    context 'when MCP servers are not available for the user' do
      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(false)
      end

      it 'returns empty arrays for every requested version id' do
        results = described_class.batch_mcp_servers_for_item_versions(
          [agent_version.id, second_agent_version.id], user)

        expect(results[agent_version.id]).to eq([])
        expect(results[second_agent_version.id]).to eq([])
      end
    end

    context 'when one version lists the same MCP server id more than once' do
      let_it_be(:item_version_with_duplicate_mcp_ids) do
        create(:ai_catalog_item_version,
          item: item,
          version: '6.0.0',
          schema_version: 1,
          definition: {
            'system_prompt' => 'Test prompt',
            'tools' => [],
            'user_prompt' => '',
            'mcp_servers' => [mcp_server1.id, mcp_server1.id, mcp_server2.id]
          })
      end

      before do
        allow(::Ai::Catalog).to receive(:mcp_servers_available?).with(user).and_return(true)
      end

      it 'dedupes repeated ids within that version' do
        batch = described_class.batch_mcp_servers_for_item_versions(
          [item_version_with_duplicate_mcp_ids.id], user)

        expect(batch[item_version_with_duplicate_mcp_ids.id]).to match_array([mcp_server1, mcp_server2])
      end
    end
  end
end
