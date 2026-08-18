# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::V1AgentDefinitionWrapper, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let(:system_prompt) { 'You are a helpful coding assistant.' }
  let(:user_prompt) { 'List all issues from project {{project}}' }
  # Tool IDs correspond to BuiltInTool records: 1 = gitlab_blob_search, 9 = create_merge_request_note
  let(:definition) do
    { system_prompt: system_prompt, user_prompt: user_prompt, tools: [1, 9] }
  end

  subject(:builder) { described_class.new(definition) }

  describe 'inheritance' do
    it 'inherits from V1' do
      expect(described_class.superclass).to eq(Ai::Catalog::DuoWorkflowPayloadBuilder::V1)
    end
  end

  describe '#build' do
    it_behaves_like 'builds valid flow configuration' do
      let(:result) { builder.build }
      let(:environment) { 'chat-partial' }
      let(:version) { 'v1' }
    end

    it 'builds workflow config correctly' do
      result = builder.build

      expect(result['environment']).to eq('chat-partial')
      expect(result['version']).to eq('v1')

      expect(result['components']).to eq([
        {
          'name' => 'agent',
          'type' => 'AgentComponent',
          'prompt_id' => 'agent_prompt',
          'inputs' => [
            { 'from' => 'context:goal', 'as' => 'goal' },
            { 'from' => 'context:project_id', 'as' => 'project' }
          ],
          'toolset' => %w[gitlab_blob_search create_merge_request_note],
          'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
        }
      ])

      expect(result['prompts']).to eq([
        {
          'prompt_id' => 'agent_prompt',
          'name' => 'agent',
          'unit_primitives' => [],
          'prompt_template' => {
            'system' => system_prompt,
            'user' => user_prompt,
            'placeholder' => 'history'
          },
          'params' => { 'timeout' => 30 }
        }
      ])

      expect(result['flow']).to eq({ 'entry_point' => 'agent' })
      expect(result['flow']).not_to have_key('inputs')

      expect(result['routers']).to eq([
        { 'from' => 'agent', 'to' => 'end' }
      ])
    end

    context 'when system_prompt is nil' do
      let(:definition) { { user_prompt: user_prompt, tools: [1, 9] } }

      it 'converts to empty string' do
        result = builder.build

        expect(result['prompts'].first['prompt_template']['system']).to eq('')
      end
    end

    context 'when user_prompt is nil' do
      let(:definition) { { system_prompt: system_prompt, tools: [1, 9] } }

      it 'converts to empty string' do
        result = builder.build

        expect(result['prompts'].first['prompt_template']['user']).to eq('')
      end
    end

    context 'when tools is nil' do
      let(:definition) { { system_prompt: system_prompt, user_prompt: user_prompt } }

      it 'uses empty array for toolset' do
        result = builder.build

        expect(result['components'].first['toolset']).to eq([])
      end
    end

    context 'when tools is empty' do
      let(:definition) { { system_prompt: system_prompt, user_prompt: user_prompt, tools: [] } }

      it 'uses empty array for toolset' do
        result = builder.build

        expect(result['components'].first['toolset']).to eq([])
      end
    end

    context 'with string keys' do
      let(:definition) { { 'system_prompt' => system_prompt, 'user_prompt' => user_prompt, 'tools' => [1] } }

      it 'resolves tool IDs to tool names' do
        result = builder.build

        expect(result['components'].first['toolset']).to eq(%w[gitlab_blob_search])
        expect(result['prompts'].first['prompt_template']['system']).to eq(system_prompt)
      end
    end
  end

  describe 'conformance with runtime path' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project, :in_group, maintainers: user) }
    let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
    let_it_be(:agent_version) { agent.versions.last }

    before do
      enable_ai_catalog
      # Validation path uses AGENT_NAME since agent ID isn't available during create.
      stub_const("#{described_class}::AGENT_NAME", "#{agent.id}/0")
    end

    it 'produces equivalent flow config as BuildFlowConfigService' do
      runtime_yaml = Ai::Catalog::Agents::BuildFlowConfigService.new(
        project: project,
        current_user: user,
        params: { agent_version: agent_version, flow_config_type: 'chat' }
      ).execute.payload[:flow_config]
      runtime_result = YAML.safe_load(runtime_yaml)

      validation_result = described_class.new(
        agent_version.definition,
        params: { user_prompt_input: Ai::Catalog::Agents::BuildFlowConfigService::USER_PROMPT_INPUT }
      ).build

      expect(validation_result).to eq(runtime_result)
    end
  end
end
