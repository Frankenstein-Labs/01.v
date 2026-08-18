# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::AuditEventMessageService, feature_category: :workflow_catalog do
  it_behaves_like 'Ai::Catalog::AuditEventMessageService' do
    let_it_be(:item_name) { 'agent' }
    let_it_be(:event_name_prefix) { 'ai_catalog_agent' }
    let_it_be(:schema_version_constant) { Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION }
    let_it_be(:project) { create(:project) }
    let_it_be_with_reload(:item) { create(:ai_catalog_agent, project: project) }

    let(:version) { item.latest_version }
    let(:params) { {} }
    let(:service) { described_class.new(event_type, item, params) }

    describe '#messages' do
      subject(:messages) { service.messages }

      before do
        version.dws_flow_config_validated = true
      end

      context 'when event_type is create_ai_catalog_agent' do
        let(:event_type) { 'create_ai_catalog_agent' }

        context 'with tools' do
          before do
            version.update!(definition: { 'tools' => [1, 2], 'system_prompt' => 'Test prompt' })
          end

          it 'returns create messages with tools' do
            expect(messages).to contain_exactly(
              "Created a new private AI agent with tools: [gitlab_blob_search, ci_linter]",
              "Created new draft version #{version.version} of AI agent"
            )
          end
        end

        context 'when agent is public' do
          before do
            item.update!(visibility: :public)
          end

          it 'returns create messages for public agent' do
            expect(messages).to contain_exactly(
              "Created a new public AI agent with tools: [gitlab_blob_search]",
              "Created new draft version #{version.version} of AI agent"
            )
          end
        end

        context 'when agent is restricted' do
          before do
            item.update!(visibility: :restricted)
          end

          it 'returns create messages for restricted agent' do
            expect(messages).to contain_exactly(
              "Created a new restricted AI agent with tools: [gitlab_blob_search]",
              "Created new draft version #{version.version} of AI agent"
            )
          end
        end

        context 'when version is released' do
          let_it_be(:released_agent, freeze: false) { create(:ai_catalog_agent, project: project) }
          let(:item) { released_agent }
          let(:version) { released_agent.latest_version }

          before do
            version.update!(definition: { 'tools' => [1, 2], 'system_prompt' => 'Test prompt' },
              release_date: Time.current)
          end

          it 'returns create messages with released version' do
            expect(messages).to contain_exactly(
              "Created a new private AI agent with tools: [gitlab_blob_search, ci_linter]",
              "Released version #{version.version} of AI agent"
            )
          end
        end

        context 'when agent has no tools' do
          before do
            version.update!(definition: { 'tools' => [], 'system_prompt' => 'Test prompt' })
          end

          it 'returns create messages with no tools message' do
            expect(messages).to contain_exactly(
              "Created a new private AI agent with no tools",
              "Created new draft version #{version.version} of AI agent"
            )
          end
        end
      end

      context 'when event_type is update_ai_catalog_agent' do
        let(:event_type) { 'update_ai_catalog_agent' }

        context 'when tools are added' do
          let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' } } }

          before do
            version.update!(definition: { 'tools' => [1, 2], 'system_prompt' => 'Old prompt' })
          end

          it 'returns tool addition message' do
            expect(messages).to contain_exactly(
              "Updated AI agent: Added tools: [ci_linter]"
            )
          end
        end

        context 'when tools are removed' do
          let(:params) { { old_definition: { 'tools' => [1, 2], 'system_prompt' => 'Old prompt' } } }

          before do
            version.update!(definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' })
          end

          it 'returns tool removal message' do
            expect(messages).to contain_exactly(
              "Updated AI agent: Removed tools: [ci_linter]"
            )
          end
        end

        context 'when system prompt is changed' do
          let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' } } }

          before do
            version.update!(definition: { 'tools' => [1], 'system_prompt' => 'New prompt' })
          end

          it 'returns system prompt change message' do
            expect(messages).to contain_exactly(
              "Updated AI agent: Changed system prompt"
            )
          end
        end

        context 'when multiple changes occur' do
          let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'Old prompt' } } }

          before do
            version.update!(definition: { 'tools' => [1, 2, 3], 'system_prompt' => 'New prompt' })
          end

          it 'returns combined update message' do
            expect(messages).to contain_exactly(
              "Updated AI agent: Added tools: [ci_linter, run_git_command], Changed system prompt"
            )
          end
        end

        context 'when visibility changes to public' do
          before do
            item.update!(visibility: :public)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI agent public')
          end
        end

        context 'when visibility changes to restricted' do
          before do
            item.update!(visibility: :restricted)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI agent restricted')
          end
        end

        context 'when visibility changes to private' do
          let_it_be(:item, freeze: false) { create(:ai_catalog_agent, :public, project: project) }

          before do
            item.update!(visibility: :private)
          end

          it 'returns visibility change message' do
            expect(messages).to contain_exactly('Made AI agent private')
          end
        end

        context 'when new version is created' do
          let(:params) { { old_definition: { 'tools' => [1], 'system_prompt' => 'You are issue planner' } } }

          before do
            new_version = create(
              :ai_catalog_agent_version,
              item: item,
              version: '2.0.0',
              definition: { 'tools' => [1, 2], 'system_prompt' => 'You are issue planner' }
            )
            item.update!(latest_version: new_version)
          end

          it 'returns version creation message' do
            expect(messages).to contain_exactly(
              "Created new draft version 2.0.0 of AI agent",
              "Updated AI agent: Added tools: [ci_linter]"
            )
          end
        end

        context 'when version is released' do
          before do
            version.update!(release_date: Time.current)
          end

          it 'returns version release message' do
            expect(messages).to contain_exactly(
              "Released version #{version.version} of AI agent"
            )
          end
        end

        context 'when the agent is updated but the version definition remains unchanged' do
          it 'returns default update message' do
            expect(messages).to eq(['Updated AI agent'])
          end
        end
      end
    end
  end
end
