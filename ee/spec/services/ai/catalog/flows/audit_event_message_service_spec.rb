# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::AuditEventMessageService, feature_category: :workflow_catalog do
  it_behaves_like 'Ai::Catalog::AuditEventMessageService' do
    let_it_be(:item_name) { 'flow' }
    let_it_be(:event_name_prefix) { 'ai_catalog_flow' }
    let_it_be(:schema_version_constant) { Ai::Catalog::ItemVersion::FLOW_SCHEMA_VERSION }
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:item) { create(:ai_catalog_flow, project: project) }

    let(:version) { item.latest_version }
    let(:params) { {} }
    let(:service) { described_class.new(event_type, item, params) }

    describe '#messages' do
      subject(:messages) { service.messages }

      context 'when event_type is create_ai_catalog_flow' do
        let(:event_type) { 'create_ai_catalog_flow' }

        let(:base_create_definition) do
          {
            'version' => 'v1',
            'environment' => 'ambient',
            'components' => [
              {
                'name' => 'agent1',
                'type' => 'AgentComponent',
                'prompt_id' => 'test_prompt'
              }
            ],
            'routers' => [],
            'flow' => { 'entry_point' => 'agent1' },
            'yaml_definition' => 'test'
          }
        end

        let(:create_definition) { base_create_definition }

        before do
          version.dws_flow_config_validated = true
          version.update!(definition: create_definition)
        end

        context 'with tools in components' do
          let(:create_definition) do
            base_create_definition.merge(
              'components' => [
                {
                  'name' => 'agent1',
                  'type' => 'AgentComponent',
                  'prompt_id' => 'test_prompt',
                  'toolset' => %w[gitlab_blob_search ci_linter]
                },
                {
                  'name' => 'step1',
                  'type' => 'DeterministicStepComponent',
                  'tool_name' => 'run_git_command'
                }
              ]
            )
          end

          it 'returns create messages with accumulated tools' do
            expect(messages).to contain_exactly(
              "Created a new private AI flow with tools: [gitlab_blob_search, ci_linter, run_git_command]",
              "Created new draft version #{version.version} of AI flow"
            )
          end
        end

        context 'when flow is public' do
          before do
            item.update!(visibility: :public)
          end

          it 'returns create messages for public flow' do
            expect(messages).to contain_exactly(
              "Created a new public AI flow with no tools",
              "Created new draft version #{version.version} of AI flow"
            )
          end
        end

        context 'when flow is restricted' do
          before do
            item.update!(visibility: :restricted)
          end

          it 'returns create messages for restricted flow' do
            expect(messages).to contain_exactly(
              "Created a new restricted AI flow with no tools",
              "Created new draft version #{version.version} of AI flow"
            )
          end
        end

        context 'when version is released' do
          before do
            version.update!(release_date: Time.current)
          end

          it 'returns create messages with released version' do
            expect(messages).to contain_exactly(
              "Created a new private AI flow with no tools",
              "Released version #{version.version} of AI flow"
            )
          end
        end
      end

      context 'when event_type is update_ai_catalog_flow' do
        let(:event_type) { 'update_ai_catalog_flow' }

        let(:base_old_definition) do
          {
            'version' => 'v1',
            'environment' => 'ambient',
            'components' => [
              {
                'name' => 'main_agent',
                'type' => 'AgentComponent',
                'prompt_id' => 'test_prompt'
              }
            ],
            'routers' => [],
            'flow' => { 'entry_point' => 'main_agent' },
            'prompts' => []
          }
        end

        let(:base_new_definition) do
          {
            'version' => 'v1',
            'environment' => 'ambient',
            'components' => [
              {
                'name' => 'main_agent',
                'type' => 'AgentComponent',
                'prompt_id' => 'test_prompt'
              }
            ],
            'routers' => [],
            'flow' => { 'entry_point' => 'main_agent' },
            'prompts' => [],
            'yaml_definition' => 'test'
          }
        end

        let(:old_definition) { base_old_definition }
        let(:new_definition) { base_new_definition }
        let(:params) { { old_definition: old_definition } }

        before do
          version.dws_flow_config_validated = true
          version.update!(definition: new_definition)
        end

        context 'when tools are added' do
          let(:new_definition) do
            base_new_definition.deep_merge(
              'components' => [
                base_new_definition['components'][0].merge('toolset' => ['read_file'])
              ]
            )
          end

          it 'returns tool addition message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Added tools: [read_file]"
            )
          end
        end

        context 'when tools are removed' do
          let(:old_definition) do
            base_old_definition.deep_merge(
              'components' => [
                base_old_definition['components'][0].merge('toolset' => %w[read_file list_dir])
              ]
            )
          end

          let(:new_definition) do
            base_new_definition.deep_merge(
              'components' => [
                base_new_definition['components'][0].merge('toolset' => ['read_file'])
              ]
            )
          end

          it 'returns tool removal message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Removed tools: [list_dir]"
            )
          end
        end

        context 'when prompts are modified' do
          let(:old_definition) do
            base_old_definition.merge(
              'prompts' => [
                {
                  'prompt_id' => 'prompt1',
                  'name' => 'prompt1',
                  'prompt_template' => { 'system' => 'You are a code helper' },
                  'unit_primitives' => []
                }
              ]
            )
          end

          let(:new_definition) do
            base_new_definition.merge(
              'prompts' => [
                {
                  'prompt_id' => 'prompt1',
                  'name' => 'prompt1',
                  'prompt_template' => { 'system' => 'You are a Issue planner helper' },
                  'unit_primitives' => []
                }
              ]
            )
          end

          it 'returns prompt modification message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Modified prompts: [prompt1]"
            )
          end
        end

        context 'when routes are added' do
          let(:new_definition) do
            base_new_definition.merge('routers' => [{ 'from' => 'agent1', 'to' => 'agent2' }])
          end

          it 'returns route addition message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Added routes: [agent1 → agent2]"
            )
          end
        end

        context 'when conditional routes are added' do
          let(:new_definition) do
            base_new_definition.merge(
              'routers' => [
                {
                  'from' => 'decide_approach',
                  'condition' => {
                    'input' => 'context:decide_approach.final_answer',
                    'routes' => {
                      'add_comment' => 'add_comment_step',
                      'create_fix' => 'create_plan_step',
                      'default_route' => 'add_comment_step'
                    }
                  }
                }
              ]
            )
          end

          it 'returns route addition message with all conditional routes' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Added routes: [decide_approach → add_comment_step, " \
                "decide_approach → create_plan_step]"
            )
          end
        end

        context 'when routes are removed including conditional routes' do
          let(:old_definition) do
            base_old_definition.merge(
              'routers' => [
                {
                  'from' => 'decide_approach',
                  'condition' => {
                    'input' => 'context:decide_approach.final_answer',
                    'routes' => {
                      'add_comment' => 'add_comment_step',
                      'create_fix' => 'create_plan_step'
                    }
                  }
                }
              ]
            )
          end

          it 'returns route removal message with all conditional routes' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Removed routes: [decide_approach → add_comment_step, " \
                "decide_approach → create_plan_step]"
            )
          end
        end

        context 'when mixing regular and conditional routes' do
          let(:old_definition) do
            base_old_definition.merge(
              'routers' => [
                { 'from' => 'agent1', 'to' => 'agent2' }
              ]
            )
          end

          let(:new_definition) do
            base_new_definition.merge(
              'routers' => [
                { 'from' => 'agent1', 'to' => 'agent2' },
                {
                  'from' => 'decide_approach',
                  'condition' => {
                    'input' => 'context:decide_approach.final_answer',
                    'routes' => {
                      'add_comment' => 'add_comment_step',
                      'create_fix' => 'create_plan_step'
                    }
                  }
                },
                { 'from' => 'agent2', 'to' => 'end' }
              ]
            )
          end

          it 'returns route addition message with both regular and conditional routes' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Added routes: [decide_approach → add_comment_step, " \
                "decide_approach → create_plan_step, agent2 → end]"
            )
          end
        end

        context 'when entry point changes' do
          let(:new_definition) do
            base_new_definition.merge('flow' => { 'entry_point' => 'agent2' })
          end

          it 'returns entry point change message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Entry point changed from 'main_agent' to 'agent2'"
            )
          end
        end

        context 'when components are added' do
          let(:new_definition) do
            base_new_definition.merge(
              'components' => base_new_definition['components'] + [
                { 'name' => 'agent2', 'type' => 'AgentComponent', 'prompt_id' => 'prompt2' }
              ]
            )
          end

          it 'returns component addition message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Added components: [agent2]"
            )
          end
        end

        context 'when environment changes' do
          let(:old_definition) { base_old_definition.merge('environment' => 'chat') }

          it 'returns environment change message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Environment changed from 'chat' to 'ambient'"
            )
          end
        end

        context 'when version changes' do
          let(:old_definition) { base_old_definition.merge('version' => 'v2') }

          it 'returns version change message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Version changed from 'v2' to 'v1'"
            )
          end
        end

        context 'when multiple changes occur' do
          let(:new_definition) do
            base_new_definition.merge(
              'components' => [
                base_new_definition['components'][0].merge('toolset' => ['read_file'])
              ],
              'routers' => [{ 'from' => 'agent1', 'to' => 'end' }],
              'prompts' => [
                {
                  'prompt_id' => 'prompt1',
                  'name' => 'prompt1',
                  'prompt_template' => { 'system' => 'You are a Issue planner helper' },
                  'unit_primitives' => []
                }
              ]
            )
          end

          it 'returns combined update message' do
            expect(messages).to contain_exactly(
              "Updated AI flow: Added tools: [read_file], Added prompts: [prompt1], Added routes: [agent1 → end]"
            )
          end
        end

        context 'when visibility changes to public' do
          before do
            item.update!(visibility: :public)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI flow public')
          end
        end

        context 'when visibility changes to restricted' do
          before do
            item.update!(visibility: :restricted)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI flow restricted')
          end
        end

        context 'when visibility changes to private' do
          let_it_be(:item, freeze: false) { create(:ai_catalog_flow, :public, project: project) }

          before do
            item.update!(visibility: :private)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI flow private')
          end
        end

        context 'when new version is created' do
          let(:old_definition) do
            base_old_definition.merge(
              'components' => [
                {
                  'name' => 'agent1',
                  'type' => 'AgentComponent',
                  'prompt_id' => 'prompt1'
                }
              ],
              'flow' => { 'entry_point' => 'agent1' }
            )
          end

          let(:new_definition) do
            base_new_definition.merge(
              'components' => [
                {
                  'name' => 'agent1',
                  'type' => 'AgentComponent',
                  'toolset' => %w[read_file],
                  'prompt_id' => 'prompt1'
                }
              ],
              'flow' => { 'entry_point' => 'agent1' }
            )
          end

          before do
            new_version = create(
              :ai_catalog_flow_version,
              item: item,
              version: '2.0.0',
              definition: new_definition,
              dws_flow_config_validated: true
            )
            item.update!(latest_version: new_version)
          end

          it 'returns version creation message' do
            expect(messages).to contain_exactly(
              "Created new draft version 2.0.0 of AI flow",
              "Updated AI flow: Added tools: [read_file]"
            )
          end
        end

        context 'when version is released' do
          before do
            version.update!(release_date: Time.current)
          end

          it 'returns version release message' do
            expect(messages).to contain_exactly(
              "Released version #{version.version} of AI flow"
            )
          end
        end

        context 'when the flow name or description updated but the version definition remains unchanged' do
          before do
            item.update!(name: "New flow name")
          end

          it 'returns default update message' do
            expect(messages).to eq(['Updated AI flow'])
          end
        end

        context 'when the flow definition changes with fields that are not audited' do
          let(:old_definition) do
            base_old_definition.merge(
              'components' => [
                {
                  'name' => 'agent1',
                  'type' => 'AgentComponent',
                  'prompt_id' => 'prompt1'
                }
              ],
              'flow' => { 'entry_point' => 'agent1' }
            )
          end

          let(:new_definition) do
            base_new_definition.merge(
              'components' => [
                {
                  'name' => 'agent1',
                  'type' => 'AgentComponent',
                  'ui_log_events' => ['on_agent_final_answer'],
                  'prompt_id' => 'prompt1'
                }
              ],
              'flow' => { 'entry_point' => 'agent1' }
            )
          end

          it 'returns default update message' do
            expect(messages).to eq(['Updated AI flow'])
          end
        end
      end
    end
  end
end
