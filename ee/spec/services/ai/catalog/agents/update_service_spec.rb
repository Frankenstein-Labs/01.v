# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::UpdateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_item_version, :released, version: '1.0.0', item: item)
  end

  let_it_be_with_reload(:latest_version) { create(:ai_catalog_item_version, version: '1.1.0', item: item) }
  let(:tool_ids) { [1, 9] }
  let(:params) do
    {
      item: item,
      name: 'New name',
      description: 'New description',
      visibility: :restricted,
      release: true,
      tools: Ai::Catalog::BuiltInTool.where(id: tool_ids),
      user_prompt: 'New user prompt',
      system_prompt: 'New system prompt'
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  before do
    enable_ai_catalog
    latest_version.dws_flow_config_validated = true
  end

  it_behaves_like Ai::Catalog::Items::BaseUpdateService do
    let(:item_schema_version) { Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION }
    let(:expected_updated_definition) do
      {
        tools: tool_ids,
        user_prompt: 'New user prompt',
        system_prompt: 'New system prompt'
      }
    end

    let(:expected_update_event_properties) do
      {
        label: 'agent',
        item_type: 'custom_agent',
        item_version: '1.1.0',
        item_schema_version: 'v1',
        custom_item_id: item.id,
        tools: 'gitlab_blob_search,create_merge_request_note'
      }
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when agent is not an agent' do
        before do
          allow(item).to receive(:agent?).and_return(false)
        end

        it_behaves_like 'an error response', 'Agent not found'
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

      context 'when updating without a definition change' do
        let(:params) { { item: item, name: 'New name' } }

        it 'does not call DWS validation and succeeds' do
          dws_client = instance_double(Ai::DuoWorkflow::DuoWorkflowService::Client)
          allow(Ai::DuoWorkflow::DuoWorkflowService::Client).to receive(:new).and_return(dws_client)
          allow(dws_client).to receive(:validate_flow_config)

          result = execute_service

          expect(result).to be_success
          expect(dws_client).not_to have_received(:validate_flow_config)
        end
      end
    end
  end

  describe 'preventing unnecessary version creation when tools are reordered' do
    let(:tool_ids) { [9, 1, 5, 2] }
    let(:system_prompt) { 'Original prompt' }
    let(:params) do
      {
        item: item,
        tools: Ai::Catalog::BuiltInTool.where(id: tool_ids)
      }
    end

    before_all do
      project.add_maintainer(user)
    end

    before do
      latest_version.update!(
        definition: { 'tools' => [9, 1, 5, 2], 'system_prompt' => 'Original prompt' },
        release_date: 1.day.ago
      )
      item.update!(latest_released_version: latest_version)
    end

    shared_examples 'creates a new version' do
      it 'creates a new version and updates with expected tool configuration' do
        expect { service.execute }.to change { item.reload.versions.count }.by(1)
        expect(item.latest_version.definition['tools']).to match_array(tool_ids)
        expect(item.latest_version.definition['system_prompt']).to eq(system_prompt)
      end
    end

    shared_examples 'does not create a new version' do
      it 'does not create a new version and preserves existing configuration' do
        expect { service.execute }.not_to change { item.reload.versions.count }
        expect(latest_version.reload.definition['tools']).to match_array(tool_ids)
        expect(latest_version.definition['system_prompt']).to eq(system_prompt)
      end
    end

    context 'when tools are reordered but contain the same IDs' do
      let(:tool_ids) { [1, 2, 5, 9] }

      it_behaves_like 'does not create a new version'
    end

    context 'when tools are actually different' do
      let(:tool_ids) { [2, 3] }

      it_behaves_like 'creates a new version'
    end

    context 'when tools include additional items but same core set' do
      let(:tool_ids) { [1, 9, 2] }

      it_behaves_like 'creates a new version'
    end

    context 'when tools are subset of original' do
      let(:tool_ids) { [1] }

      it_behaves_like 'creates a new version'
    end

    context 'when only system_prompt is provided' do
      let(:system_prompt) { 'Updated system prompt' }
      let(:params) { { system_prompt: system_prompt, item: item } }

      it_behaves_like 'creates a new version'
    end
  end

  describe 'when mcp_servers are passed' do
    let_it_be(:mcp_server1) { create(:ai_catalog_mcp_server) }
    let_it_be(:mcp_server2) { create(:ai_catalog_mcp_server) }

    before_all do
      project.add_maintainer(user)
    end

    before do
      latest_version.update!(
        definition: {
          'mcp_servers' => [mcp_server1.id, mcp_server2.id],
          'system_prompt' => 'Original prompt',
          'tools' => []
        },
        release_date: 1.day.ago
      )
      item.update!(latest_released_version: latest_version)
    end

    context 'when mcp_servers are updated with new servers' do
      let_it_be(:mcp_server3) { create(:ai_catalog_mcp_server) }

      let(:params) do
        {
          item: item,
          mcp_servers: [mcp_server1.id, mcp_server3.id]
        }
      end

      it 'creates a new version with updated mcp_servers' do
        expect { service.execute }.to change { item.reload.versions.count }.by(1)
        expect(item.latest_version.definition['mcp_servers']).to match_array([mcp_server1.id, mcp_server3.id])
      end
    end

    context 'when mcp_servers are reordered but contain the same IDs' do
      let(:params) do
        {
          item: item,
          mcp_servers: [mcp_server2.id, mcp_server1.id]
        }
      end

      it 'does not create a new version and preserves existing configuration' do
        expect { service.execute }.not_to change { item.reload.versions.count }
        expect(latest_version.reload.definition['mcp_servers']).to match_array([mcp_server1.id, mcp_server2.id])
      end
    end
  end

  describe 'when mcp_tools are passed' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      latest_version.update!(
        definition: {
          'mcp_tools' => %w[search create_issue],
          'system_prompt' => 'Original prompt',
          'tools' => []
        },
        release_date: 1.day.ago
      )
      item.update!(latest_released_version: latest_version)
    end

    context 'when mcp_tools are updated with new names' do
      let(:params) do
        {
          item: item,
          mcp_tools: %w[get_issue create_workitem_note]
        }
      end

      it 'creates a new version with updated mcp_tools' do
        expect { service.execute }.to change { item.reload.versions.count }.by(1)
        expect(item.latest_version.definition['mcp_tools']).to match_array(%w[get_issue create_workitem_note])
      end
    end

    context 'when mcp_tools are reordered but contain the same names' do
      let(:params) do
        {
          item: item,
          mcp_tools: %w[create_issue search]
        }
      end

      it 'does not create a new version and preserves existing configuration' do
        expect { service.execute }.not_to change { item.reload.versions.count }
        expect(latest_version.reload.definition['mcp_tools']).to match_array(%w[search create_issue])
      end
    end
  end

  describe 'audit events' do
    let(:params) { super().except(:visibility).merge(public: true) }
    let(:execute_service) do
      service.execute
    end

    before_all do
      project.add_maintainer(user)
    end

    it 'creates audit events for the changes', :aggregate_failures do
      expect { execute_service }.to change { AuditEventReader.count }.by(3)

      audit_events = AuditEventReader.last(3)

      expect(audit_events[0]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[0].details).to include(
        custom_message: 'Updated AI agent: Added tools: [create_merge_request_note], Changed system prompt',
        event_name: "update_ai_catalog_agent",
        target_type: "Ai::Catalog::Item"
      )

      expect(audit_events[1]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      expect(audit_events[1].details).to include(
        custom_message: 'Made AI agent public'
      )

      expect(audit_events[2]).to have_attributes(
        author: user,
        entity_type: 'Project',
        entity_id: project.id
      )
      expect(audit_events[2].details).to include(
        custom_message: 'Released version 1.1.0 of AI agent'
      )
    end

    context 'when update fails' do
      before do
        allow(item).to receive(:save).and_return(false)
        item.errors.add(:base, 'Item cannot be updated')
      end

      it 'does not create an audit event' do
        expect { execute_service }.not_to change { AuditEventReader.count }
      end
    end
  end
end
