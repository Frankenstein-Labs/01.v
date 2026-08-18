# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServerBlockStatusBatchLoader, feature_category: :workflow_catalog do
  include GraphqlHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:group) { create(:group, organization: organization) }
  let_it_be(:subgroup) { create(:group, parent: group, organization: organization) }
  let_it_be(:project) { create(:project, group: subgroup, organization: organization) }

  let_it_be(:server1) { create(:ai_catalog_mcp_server, organization: organization) }
  let_it_be(:server2) { create(:ai_catalog_mcp_server, organization: organization) }

  def block!(namespace, server)
    create(:ai_catalog_mcp_server_block, namespace: namespace, mcp_server: server, organization: organization)
  end

  describe '.load_for' do
    context 'when the server is not blocked on the namespace or any ancestor' do
      it 'returns ACTIVE' do
        result = batch_sync { described_class.load_for(server1, group) }

        expect(result).to eq(described_class::ACTIVE)
      end
    end

    context 'when the server is blocked directly on the namespace' do
      before do
        block!(group, server1)
      end

      it 'returns BLOCKED' do
        result = batch_sync { described_class.load_for(server1, group) }

        expect(result).to eq(described_class::BLOCKED)
      end
    end

    context 'when the server is blocked on an ancestor group' do
      before do
        block!(group, server1)
      end

      it 'returns BLOCKED_BY_ANCESTOR for a descendant subgroup' do
        result = batch_sync { described_class.load_for(server1, subgroup) }

        expect(result).to eq(described_class::BLOCKED_BY_ANCESTOR)
      end

      it 'returns BLOCKED_BY_ANCESTOR for a descendant project namespace' do
        result = batch_sync { described_class.load_for(server1, project.project_namespace) }

        expect(result).to eq(described_class::BLOCKED_BY_ANCESTOR)
      end
    end

    context 'when the server is blocked directly on a project namespace' do
      before do
        block!(project.project_namespace, server1)
      end

      it 'returns BLOCKED for that project namespace' do
        result = batch_sync { described_class.load_for(server1, project.project_namespace) }

        expect(result).to eq(described_class::BLOCKED)
      end
    end

    it 'batches servers for the same namespace and resolves each status independently', :aggregate_failures do
      block!(group, server1)

      blocked, active = batch_sync do
        [
          described_class.load_for(server1, group),
          described_class.load_for(server2, group)
        ]
      end

      expect(blocked).to eq(described_class::BLOCKED)
      expect(active).to eq(described_class::ACTIVE)
    end
  end
end
