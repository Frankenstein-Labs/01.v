# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::McpServers::SetBlockService, feature_category: :workflow_catalog do
  let_it_be(:organization) { create(:organization) }
  let_it_be_with_reload(:group) { create(:group, organization: organization) }
  let_it_be(:user) { create(:user) }
  let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, organization: organization) }

  let(:blocked) { true }

  subject(:response) do
    described_class.new(container: group, mcp_server: mcp_server, current_user: user, blocked: blocked).execute
  end

  before do
    allow(user).to receive(:can?).and_call_original
    allow(Ability).to receive(:allowed?).and_call_original
    allow(Ability).to receive(:allowed?)
      .with(user, :block_ai_catalog_mcp_server, group).and_return(true)
  end

  describe '#execute' do
    context 'when the user is authorized' do
      context 'when blocking' do
        it 'creates a block record and returns success', :aggregate_failures do
          expect { response }.to change { Ai::Catalog::McpServerBlock.count }.by(1)
          expect(response).to be_success
          expect(response.payload[:mcp_server]).to eq(mcp_server)

          block = Ai::Catalog::McpServerBlock.find_by(
            namespace_id: group.id, ai_catalog_mcp_server_id: mcp_server.id
          )
          expect(block).to have_attributes(
            namespace_id: group.id,
            ai_catalog_mcp_server_id: mcp_server.id,
            organization_id: organization.id,
            created_by_id: user.id
          )
        end

        context 'when a block already exists' do
          before do
            create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server, organization: organization)
          end

          it 'is idempotent and does not create a duplicate', :aggregate_failures do
            expect { response }.not_to change { Ai::Catalog::McpServerBlock.count }
            expect(response).to be_success
          end
        end
      end

      context 'when allowing (blocked: false)' do
        let(:blocked) { false }

        context 'when an own block exists' do
          before do
            create(:ai_catalog_mcp_server_block, namespace: group, mcp_server: mcp_server, organization: organization)
          end

          it 'destroys the block', :aggregate_failures do
            expect { response }.to change { Ai::Catalog::McpServerBlock.count }.by(-1)
            expect(response).to be_success
          end
        end

        context 'when no own block exists (inherited only)' do
          it 'is a no-op and returns success', :aggregate_failures do
            expect { response }.not_to change { Ai::Catalog::McpServerBlock.count }
            expect(response).to be_success
          end
        end
      end
    end

    context 'when the user is not authorized' do
      before do
        allow(Ability).to receive(:allowed?)
          .with(user, :block_ai_catalog_mcp_server, group).and_return(false)
      end

      it 'returns an error and does not change records', :aggregate_failures do
        expect { response }.not_to change { Ai::Catalog::McpServerBlock.count }
        expect(response).to be_error
        expect(response.message).to include('You have insufficient permissions')
      end
    end

    context 'when the MCP server belongs to a different organization' do
      let_it_be(:mcp_server) { create(:ai_catalog_mcp_server, organization: create(:organization)) }

      it 'returns an error', :aggregate_failures do
        expect(response).to be_error
        expect(response.message).to include('MCP server does not belong to this organization')
      end
    end

    context 'with a project container' do
      let_it_be_with_reload(:project) { create(:project, group: group, organization: organization) }

      subject(:response) do
        described_class.new(container: project, mcp_server: mcp_server, current_user: user, blocked: blocked).execute
      end

      before do
        allow(Ability).to receive(:allowed?)
          .with(user, :block_ai_catalog_mcp_server, project).and_return(true)
      end

      it 'stores the block against the project namespace', :aggregate_failures do
        expect { response }.to change { Ai::Catalog::McpServerBlock.count }.by(1)
        expect(response).to be_success

        block = Ai::Catalog::McpServerBlock.find_by(
          namespace_id: project.project_namespace_id, ai_catalog_mcp_server_id: mcp_server.id
        )
        expect(block).to be_present
      end
    end
  end
end
