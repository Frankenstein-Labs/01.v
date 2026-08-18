# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::CreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:maintainer) { create(:user) }
  let_it_be(:project) { create(:project, :in_group, maintainers: maintainer) }

  let(:user) { maintainer }
  let(:params) do
    {
      name: 'Agent',
      description: 'Description',
      visibility: :restricted,
      tools: [Ai::Catalog::BuiltInTool.find(1)],
      system_prompt: 'A',
      user_prompt: 'B'
    }
  end

  before do
    enable_ai_catalog
  end

  subject(:service) { described_class.new(project: project, current_user: user, params: params) }

  it_behaves_like Ai::Catalog::Items::BaseCreateService do
    let(:expected_item_type) { Ai::Catalog::Item::AGENT_TYPE }
    let(:expected_item_schema_version) { Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION }
    let(:expected_audit_event_create_item_message) do
      'Created a new restricted AI agent with tools: [gitlab_blob_search]'
    end

    let(:expected_audit_event_item_name) { 'AI agent' }
    let(:expected_updated_definition) do
      {
        mcp_servers: [],
        mcp_tools: [],
        system_prompt: params[:system_prompt],
        tools: [1],
        user_prompt: params[:user_prompt]
      }
    end

    let(:expected_create_event_properties) do
      {
        label: 'agent',
        item_type: 'custom_agent',
        item_version: '1.0.0',
        item_schema_version: 'v1',
        custom_item_id: kind_of(Integer),
        tools: 'gitlab_blob_search'
      }
    end

    context 'when DWS returns validation errors' do
      before do
        allow_next_instance_of(Ai::DuoWorkflow::DuoWorkflowService::Client) do |client|
          allow(client).to receive(:validate_flow_config)
            .and_return(ServiceResponse.error(message: ['Component missing input variables: goal']))
        end
      end

      it_behaves_like 'an error response', ['Component missing input variables: goal']
    end
  end

  context 'when user does not have create_ai_catalog_agent permission' do
    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(user, :create_ai_catalog_agent, project).and_return(false)
    end

    it 'returns an error response' do
      result = service.execute

      expect(result).to be_error
      expect(result.message).to contain_exactly('You have insufficient permissions')
    end

    it 'does not create an item' do
      expect { service.execute }.not_to change { Ai::Catalog::Item.count }
    end
  end

  context 'when mcp_tools are provided' do
    let(:params) { super().merge(mcp_tools: %w[search create_issue]) }

    it 'creates a catalog item with mcp_tools in definition' do
      expect { service.execute }.to change { Ai::Catalog::Item.count }.by(1)

      item = Ai::Catalog::Item.last
      expect(item.latest_version.definition['mcp_tools']).to match_array(%w[search create_issue])
    end
  end

  context 'when mcp_servers are provided' do
    let_it_be(:mcp_server1) { create(:ai_catalog_mcp_server) }
    let_it_be(:mcp_server2) { create(:ai_catalog_mcp_server) }
    let(:params) { super().merge(mcp_servers: [mcp_server1.id, mcp_server2.id]) }

    it 'creates a catalog item with mcp_servers in definition' do
      expect { service.execute }.to change { Ai::Catalog::Item.count }.by(1)

      item = Ai::Catalog::Item.last
      expect(item.latest_version.definition['mcp_servers']).to match_array([mcp_server1.id, mcp_server2.id])
    end
  end
end
