# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::FoundationalFlowStartParamsResolver, feature_category: :duo_agent_platform do
  describe '.call' do
    let_it_be(:project) { create(:project, :in_group) }

    context 'when reference is not a known foundational flow' do
      it 'returns an empty hash' do
        expect(described_class.call('unknown/v1', project)).to eq({})
      end
    end

    context 'with developer/v1' do
      let(:reference) { 'developer/v1' }

      it 'returns versioning params with version ^2.0.0' do
        expect(described_class.call(reference, project)).to eq(
          flow_config_id: 'developer',
          flow_config_schema_version: 'v1',
          flow_version: '^2.0.0'
        )
      end

      # Orbit no longer forks the flow config: it is delivered as a skill by
      # Gitlab::DuoWorkflow::OrbitLocalSetup, so the version must not change.
      context 'when duo_developer_orbit is enabled and orbit master toggle is on' do
        let_it_be(:user) { create(:user) }

        before do
          stub_feature_flags(duo_developer_orbit: user)
          user.user_preference.update!(orbit_settings: { 'enabled' => true })
        end

        it 'returns developer/v1 with the default flow version' do
          expect(described_class.call(reference, project, user: user)).to eq(
            flow_config_id: 'developer',
            flow_config_schema_version: 'v1',
            flow_version: '^2.0.0'
          )
        end
      end
    end

    context 'with fix_pipeline/v1' do
      let(:reference) { 'fix_pipeline/v1' }

      before do
        stub_feature_flags(fix_pipeline_experimental: false)
      end

      it 'returns versioning params with version 1.0.0' do
        expect(described_class.call(reference, project)).to eq(
          flow_config_id: 'fix_pipeline',
          flow_config_schema_version: 'v1',
          flow_version: '1.0.0'
        )
      end

      context 'when fix_pipeline_experimental is enabled for the project' do
        before do
          stub_feature_flags(fix_pipeline_experimental: project)
        end

        it 'overrides to fix_pipeline/experimental' do
          expect(described_class.call(reference, project)).to eq(
            flow_config_id: 'fix_pipeline',
            flow_config_schema_version: 'experimental',
            flow_version: '1.0.0'
          )
        end
      end

      context 'when fix_pipeline_experimental is enabled for the root ancestor' do
        before do
          stub_feature_flags(fix_pipeline_experimental: project.root_ancestor)
        end

        it 'overrides to fix_pipeline/experimental' do
          expect(described_class.call(reference, project)).to eq(
            flow_config_id: 'fix_pipeline',
            flow_config_schema_version: 'experimental',
            flow_version: '1.0.0'
          )
        end
      end
    end

    context 'with code_review/v1' do
      it 'returns the flow params unchanged' do
        expect(described_class.call('code_review/v1', project)).to eq(
          flow_config_id: 'code_review',
          flow_config_schema_version: 'v1',
          flow_version: '1.0.0'
        )
      end
    end

    context 'when container is a namespace' do
      let_it_be(:namespace) { create(:group) }

      it 'works with a namespace container' do
        expect(described_class.call('code_review/v1', namespace)).to eq(
          flow_config_id: 'code_review',
          flow_config_schema_version: 'v1',
          flow_version: '1.0.0'
        )
      end
    end

    context 'with mocked Foundational Chat Agents' do
      include_context 'with mocked Foundational Chat Agents'

      let(:mocked_foundational_chat_agents) do
        [
          foundational_duo_chat_agent.merge(flow_version: '^1.0.0'),
          foundational_chat_agent_1.merge(flow_version: '^1.0.0'),
          foundational_chat_agent_2
        ]
      end

      context 'with a schema version in the reference' do
        it 'returns versioning params from the foundational chat agent' do
          expect(described_class.call('agent_1/experimental', project)).to eq(
            flow_config_id: 'agent_1',
            flow_config_schema_version: 'experimental',
            flow_version: '^1.0.0'
          )
        end
      end

      context 'without a schema version in the reference' do
        it 'returns versioning params with nil schema_version' do
          expect(described_class.call('chat', project)).to eq(
            flow_config_id: 'chat',
            flow_config_schema_version: nil,
            flow_version: '^1.0.0'
          )
        end
      end

      context 'when the foundational chat agent has no flow_version' do
        it 'returns an empty hash' do
          expect(described_class.call('agent_2/experimental', project)).to eq({})
        end
      end
    end
  end
end
