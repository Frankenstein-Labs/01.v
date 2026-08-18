# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::DuoWorkflowPayloadBuilder::V1, feature_category: :workflow_catalog do
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:flow_item, freeze: false) { create(:ai_catalog_flow, project: project) }
  let_it_be(:agent_item_1, freeze: false) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:agent_item_2, freeze: false) { create(:ai_catalog_item, :agent, project: project) }
  let_it_be(:tool_ids) { [1, 2, 5] } # 1 => "gitlab_blob_search" 2 => 'ci_linter', 5 =>  'create_epic'

  let(:params) { {} }
  let(:flow_environment) { 'ambient' }
  let(:pinned_version_prefix) { nil }

  let_it_be(:agent_definition, freeze: false) do
    {
      'system_prompt' => 'Talk like a pirate!',
      'user_prompt' => 'What is a leap year?',
      'tools' => tool_ids
    }
  end

  let_it_be(:agent1_v1, freeze: false) do
    create(:ai_catalog_agent_version, item: agent_item_1, definition: agent_definition, version: '1.1.0')
  end

  let_it_be(:agent2_v1) do
    create(:ai_catalog_agent_version, item: agent_item_2, definition: agent_definition, version: '1.1.1')
  end

  let_it_be(:agent2_v2) do
    definition = {
      'system_prompt' => 'Adopt the persona of a sharp comedian',
      'user_prompt' => 'Tell me a clever and funny joke',
      'tools' => [3] # 3 => 'run_git_command'
    }
    create(:ai_catalog_agent_version, item: agent_item_2, definition: definition, version: '1.2.0')
  end

  let_it_be(:flow_definition) do
    {
      'triggers' => [1],
      'steps' => [
        { 'agent_id' => agent_item_1.id, 'current_version_id' => agent1_v1.id, 'pinned_version_prefix' => nil },
        { 'agent_id' => agent_item_2.id, 'current_version_id' => agent2_v1.id, 'pinned_version_prefix' => nil }
      ]
    }
  end

  let_it_be(:flow_version) do
    create(:ai_catalog_agent_referenced_flow_version, item: flow_item, definition: flow_definition, version: '2.1.0',
      dws_flow_config_validated: true)
  end

  subject(:builder) { described_class.new(flow_item, pinned_version_prefix:, flow_environment:, params:) }

  describe 'inheritance' do
    it 'inherits from Base' do
      expect(described_class.superclass).to eq(Ai::Catalog::DuoWorkflowPayloadBuilder::Base)
    end
  end

  describe 'constants' do
    it 'defines expected constants' do
      expect(described_class::FLOW_VERSION).to eq('v1')
      expect(described_class::AGENT_COMPONENT_TYPE).to eq('AgentComponent')
      expect(described_class::DUO_FLOW_TIMEOUT).to eq(30)
      expect(described_class::PLACEHOLDER_VALUE).to eq('history')
    end
  end

  describe '#build' do
    describe 'flow_environment' do
      let_it_be(:flow_environment) { 'my_flow_environment' }

      it 'sets the environment to the given flow_environment' do
        result = builder.build

        expect(result['environment']).to eq('my_flow_environment')
      end
    end

    context 'when user prompt input is passed as a parameter' do
      let(:params) { super().merge(user_prompt_input: "test input") }

      it 'adds it to the user prompt' do
        result = builder.build

        expect(result['prompts'][0]['prompt_template']['user']).to eq('test input')
      end
    end

    context 'when flow has no agents' do
      let_it_be(:empty_steps_definition) { { 'triggers' => [1], 'steps' => [] } }
      let_it_be(:flow_item, freeze: false) { create(:ai_catalog_flow, project: project) }
      let_it_be(:empty_steps_version) do
        create(:ai_catalog_agent_referenced_flow_version, item: flow_item, definition: empty_steps_definition,
          version: '2.1.0')
      end

      it_behaves_like 'invalid flow configuration'
    end

    context 'when flow has single agent' do
      let_it_be_with_reload(:flow_item) { create(:ai_catalog_flow, project: project) }

      let_it_be(:single_agent_flow_definition) do
        {
          'triggers' => [1],
          'steps' => [{
            'agent_id' => agent_item_1.id, 'current_version_id' => agent1_v1.id, 'pinned_version_prefix' => nil
          }]
        }
      end

      let_it_be(:single_agent_flow_version) do
        create(
          :ai_catalog_agent_referenced_flow_version,
          item: flow_item,
          definition: single_agent_flow_definition,
          version: '2.2.0'
        )
      end

      include_examples 'builds valid flow configuration' do
        let(:result) { builder.build }
        let(:environment) { 'ambient' }
        let(:version) { 'v1' }
      end

      it 'builds workflow with single component correctly', :aggregate_failures do
        agent_item_1_flow_id = "#{agent_item_1.id}/0"
        result = builder.build

        expect(result['components']).to eq([
          {
            'name' => agent_item_1_flow_id,
            'type' => 'AgentComponent',
            'prompt_id' => "#{agent_item_1_flow_id}_prompt",
            'inputs' => [
              { 'from' => 'context:goal', 'as' => 'goal' },
              { 'from' => 'context:project_id', 'as' => 'project' }
            ],
            'toolset' => %w[gitlab_blob_search ci_linter create_epic],
            'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
          }
        ])
        expect(result['prompts']).to eq([
          {
            'prompt_id' => "#{agent_item_1_flow_id}_prompt",
            'name' => agent_item_1_flow_id,
            'unit_primitives' => [],
            'prompt_template' => {
              'system' => agent1_v1.def_system_prompt,
              'user' => agent1_v1.def_user_prompt,
              'placeholder' => described_class::PLACEHOLDER_VALUE
            },
            'params' => {
              'timeout' => described_class::DUO_FLOW_TIMEOUT
            }
          }
        ])
        expect(result['flow']['entry_point']).to eq(agent_item_1_flow_id)
        expect(result['flow']).not_to have_key('inputs')
        expect(result['routers']).to eq([
          { 'from' => agent_item_1_flow_id, 'to' => 'end' }
        ])
      end

      context 'when the agent is foundational' do
        include_context 'with mocked Foundational Chat Agents'

        let(:mocked_foundational_chat_agents) do
          [{ id: 1, reference: 'duo_planner', version: 'v1', name: 'Planner', description: 'Planner agent',
             global_catalog_id: agent_item_1.id }]
        end

        before do
          stub_saas_features(gitlab_duo_saas_only: true)
        end

        it 'includes orbit inputs', :aggregate_failures do
          result = builder.build

          expect(result['flow']['inputs']).to eq([described_class::ORBIT_CONTEXT_FLOW_INPUT])
          expect(result['components'].first['inputs']).to include(described_class::ORBIT_ENABLED_INPUT)
        end
      end

      describe 'version handling' do
        let_it_be(:new_flow_version) do
          definition = {
            'triggers' => [],
            'steps' => [{
              'agent_id' => agent_item_2.id, 'current_version_id' => agent2_v1.id, 'pinned_version_prefix' => nil
            }]
          }
          create(:ai_catalog_agent_referenced_flow_version, item: flow_item, definition: definition,
            version: '2.3.0')
        end

        context 'when no version is pinned' do
          it 'selects the latest flow version' do
            result = builder.build

            expect(result['flow']['entry_point']).to eq("#{agent_item_2.id}/0")
          end
        end

        context 'when flow version is fully pinned' do
          let(:pinned_version_prefix) { '2.3.0' }

          it 'selects the correct flow version and child versions' do
            result = builder.build

            expect(result['flow']['entry_point']).to eq("#{agent_item_2.id}/0")
            expect(result['components'].first['toolset']).to contain_exactly(
              'ci_linter', 'create_epic', 'gitlab_blob_search'
            )
          end
        end
      end
    end

    context 'when flow has multiple agents' do
      include_examples 'builds valid flow configuration' do
        let(:result) { builder.build }
        let(:environment) { 'ambient' }
        let(:version) { 'v1' }
      end

      it 'builds workflow with multiple components correctly', :aggregate_failures do
        agent_item_1_flow_id = "#{agent_item_1.id}/0"
        agent_item_2_flow_id = "#{agent_item_2.id}/1"

        expect(result['components']).to eq([
          {
            'name' => agent_item_1_flow_id,
            'type' => 'AgentComponent',
            'prompt_id' => "#{agent_item_1_flow_id}_prompt",
            'inputs' => [
              { 'from' => 'context:goal', 'as' => 'goal' },
              { 'from' => 'context:project_id', 'as' => 'project' }
            ],
            'toolset' => %w[gitlab_blob_search ci_linter create_epic],
            'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
          },
          {
            'name' => agent_item_2_flow_id,
            'type' => 'AgentComponent',
            'prompt_id' => "#{agent_item_2_flow_id}_prompt",
            'inputs' => [
              { 'from' => 'context:goal', 'as' => 'goal' },
              { 'from' => 'context:project_id', 'as' => 'project' },
              { 'from' => "context:#{agent_item_1_flow_id}.final_answer", 'as' => 'previous_agent_answer' },
              { 'from' => "conversation_history:#{agent_item_1_flow_id}", 'as' => 'previous_agent_chat' }
            ],
            'toolset' => %w[run_git_command],
            'ui_log_events' => %w[on_tool_execution_success on_agent_final_answer on_tool_execution_failed]
          }
        ])
        expect(result['prompts']).to eq([
          {
            'prompt_id' => "#{agent_item_1_flow_id}_prompt",
            'name' => agent_item_1_flow_id,
            'unit_primitives' => [],
            'prompt_template' => {
              'system' => agent1_v1.def_system_prompt,
              'user' => agent1_v1.def_user_prompt,
              'placeholder' => described_class::PLACEHOLDER_VALUE
            },
            'params' => {
              'timeout' => described_class::DUO_FLOW_TIMEOUT
            }
          },
          {
            'prompt_id' => "#{agent_item_2_flow_id}_prompt",
            'name' => agent_item_2_flow_id,
            'unit_primitives' => [],
            'prompt_template' => {
              'system' => agent2_v2.def_system_prompt,
              'user' => agent2_v2.def_user_prompt,
              'placeholder' => described_class::PLACEHOLDER_VALUE
            },
            'params' => {
              'timeout' => described_class::DUO_FLOW_TIMEOUT
            }
          }
        ])
        expect(result['routers']).to eq([
          { 'from' => agent_item_1_flow_id, 'to' => agent_item_2_flow_id },
          { 'from' => agent_item_2_flow_id, 'to' => 'end' }
        ])
        expect(result['flow']['entry_point']).to eq(agent_item_1_flow_id)
        expect(result['flow']).not_to have_key('inputs')
      end

      context 'when one agent is foundational' do
        include_context 'with mocked Foundational Chat Agents'

        let(:mocked_foundational_chat_agents) do
          [{ id: 1, reference: 'duo_planner', version: 'v1', name: 'Planner', description: 'Planner agent',
             global_catalog_id: agent_item_1.id }]
        end

        before do
          stub_saas_features(gitlab_duo_saas_only: true)
        end

        it 'includes orbit inputs only for the foundational agent', :aggregate_failures do
          result = builder.build

          expect(result['flow']['inputs']).to eq([described_class::ORBIT_CONTEXT_FLOW_INPUT])
          expect(result['components'].first['inputs']).to include(described_class::ORBIT_ENABLED_INPUT)
          expect(result['components'].last['inputs']).not_to include(described_class::ORBIT_ENABLED_INPUT)
        end
      end

      it 'verifies all components have unique names' do
        component_names = result['components'].pluck('name')

        expect(component_names).to contain_exactly(
          "#{agent_item_1.id}/0",
          "#{agent_item_2.id}/1"
        )
      end
    end
  end
end
