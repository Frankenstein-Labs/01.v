# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServerBlock, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization').required }
    it { is_expected.to belong_to(:namespace).required }

    it 'belongs to an mcp_server' do
      is_expected.to belong_to(:mcp_server)
        .class_name('Ai::Catalog::McpServer')
        .with_foreign_key(:ai_catalog_mcp_server_id)
        .inverse_of(:blocks)
        .required
    end

    it { is_expected.to belong_to(:created_by).class_name('User').optional }
  end

  describe 'validations' do
    subject { build(:ai_catalog_mcp_server_block) }

    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:ai_catalog_mcp_server_id) }
  end

  describe 'scopes' do
    let_it_be(:block) { create(:ai_catalog_mcp_server_block) }
    let_it_be(:other_block) { create(:ai_catalog_mcp_server_block) }

    describe '.for_namespaces' do
      it 'returns blocks for the given namespaces' do
        expect(described_class.for_namespaces([block.namespace_id])).to contain_exactly(block)
      end
    end

    describe '.for_servers' do
      it 'returns blocks for the given servers' do
        expect(described_class.for_servers([block.ai_catalog_mcp_server_id])).to contain_exactly(block)
      end
    end
  end

  describe '.blocked_server_ids_for' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:subgroup) { create(:group, parent: group, organization: organization) }
    let_it_be(:server) { create(:ai_catalog_mcp_server, organization: organization) }
    let_it_be(:other_server) { create(:ai_catalog_mcp_server, organization: organization) }

    let(:server_ids) { [server.id, other_server.id] }

    subject(:blocked_ids) do
      described_class.blocked_server_ids_for(namespace, server_ids).map(&:ai_catalog_mcp_server_id)
    end

    context 'with a block on the namespace itself' do
      let(:namespace) { group }

      before do
        create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: server, organization: organization)
      end

      it 'returns the blocked server' do
        is_expected.to contain_exactly(server.id)
      end

      context 'when the blocked server is not in the requested server_ids' do
        let(:server_ids) { [other_server.id] }

        it 'excludes it' do
          is_expected.to be_empty
        end
      end
    end

    context 'with a block on an ancestor namespace' do
      let(:namespace) { subgroup }

      before do
        create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: server, organization: organization)
      end

      it 'returns the server blocked by the ancestor (cascade)' do
        is_expected.to contain_exactly(server.id)
      end
    end

    context 'when no block exists for the namespace or its ancestors' do
      let(:namespace) { subgroup }

      it 'returns nothing' do
        is_expected.to be_empty
      end
    end
  end

  describe '.block!' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:server) { create(:ai_catalog_mcp_server, organization: organization) }
    let_it_be(:user) { create(:user) }

    it 'creates a block for the namespace and server', :aggregate_failures do
      expect { described_class.block!(namespace: group, mcp_server: server, created_by: user) }
        .to change { described_class.count }.by(1)

      block = described_class.find_by(namespace_id: group.id, ai_catalog_mcp_server_id: server.id)
      expect(block).to have_attributes(organization_id: organization.id, created_by_id: user.id)
    end

    it 'is idempotent and does not duplicate when already blocked (race-safe)' do
      # Uses safe_find_or_create_by! so a concurrent insert is recovered rather than raising.
      described_class.block!(namespace: group, mcp_server: server, created_by: user)

      expect { described_class.block!(namespace: group, mcp_server: server, created_by: user) }
        .not_to change { described_class.count }
    end
  end

  describe '.unblock!' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:server) { create(:ai_catalog_mcp_server, organization: organization) }

    it 'removes the namespace own block for the server' do
      create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: server, organization: organization)

      expect { described_class.unblock!(namespace: group, mcp_server: server) }
        .to change { described_class.count }.by(-1)
    end

    it 'is a no-op when no block exists' do
      expect { described_class.unblock!(namespace: group, mcp_server: server) }
        .not_to change { described_class.count }
    end
  end

  describe '.blocked_namespace_server_pairs' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:server) { create(:ai_catalog_mcp_server, organization: organization) }
    let_it_be(:other_server) { create(:ai_catalog_mcp_server, organization: organization) }

    before do
      create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: server, organization: organization)
    end

    it 'returns [namespace_id, server_id] pairs for blocked servers only' do
      pairs = described_class.blocked_namespace_server_pairs([group.id], [server.id, other_server.id])

      expect(pairs).to contain_exactly([group.id, server.id])
    end
  end
end
