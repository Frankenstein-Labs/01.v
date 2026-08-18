# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::V1AgentWrapper, :aggregate_failures, feature_category: :workflow_catalog do
  let_it_be(:project) { create(:project) }
  let_it_be(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be(:agent_version) { agent.versions.last }
  let_it_be(:wrapped_agent_response) { Ai::Catalog::WrappedAgentFlowBuilder.new(agent, agent_version).execute }
  let_it_be(:flow) { wrapped_agent_response.payload[:flow] }
  let_it_be(:flow_version) { flow.versions.last }
  let(:user_prompt_input) { 'List all issues from project {{project}}' }

  let(:flow_environment) { 'chat-partial' }
  let(:params) { { user_prompt_input: user_prompt_input } }

  subject(:builder) { described_class.new(flow, flow_version, flow_environment:, params:) }

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
      agent_flow_id = "#{agent.id}/0"
      result = builder.build

      expect(result['components']).to eq([
        {
          'name' => agent_flow_id,
          'type' => 'AgentComponent',
          'prompt_id' => "#{agent_flow_id}_prompt",
          'inputs' => [
            { 'from' => 'context:goal', 'as' => 'goal' },
            { 'from' => 'context:project_id', 'as' => 'project' }
          ],
          'toolset' => %w[gitlab_blob_search],
          'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
        }
      ])
      expect(result['prompts']).to eq([
        {
          'prompt_id' => "#{agent_flow_id}_prompt",
          'name' => agent_flow_id,
          'unit_primitives' => [],
          'prompt_template' => {
            'system' => agent_version.def_system_prompt,
            'user' => user_prompt_input,
            'placeholder' => described_class::PLACEHOLDER_VALUE
          },
          "params" => { "timeout" => 30 }
        }
      ])
      expect(result['flow']['entry_point']).to eq(agent_flow_id)
      expect(result['flow']).not_to have_key('inputs')
      expect(result['routers']).to eq([
        { 'from' => agent_flow_id, 'to' => 'end' }
      ])
    end
  end
end
