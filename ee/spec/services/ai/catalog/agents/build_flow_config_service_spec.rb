# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Agents::BuildFlowConfigService, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:guest) { create(:user) }
  let_it_be(:organization) { create(:common_organization) }
  let_it_be(:project) { create(:project, organization: organization, guests: guest) }
  let_it_be(:agent) { create(:ai_catalog_agent, organization: organization, project: project) }
  let_it_be(:agent_version) { agent.versions.last }

  let_it_be(:service_params) do
    {
      agent_version: agent_version,
      flow_config_type: 'chat'
    }
  end

  let(:current_user) { guest }

  let(:service) do
    described_class.new(
      project: project,
      current_user: current_user,
      params: service_params
    )
  end

  let(:json_config) do
    {
      'version' => 'v1',
      'environment' => 'chat-partial',
      'components' => be_an(Array),
      'routers' => be_an(Array),
      'flow' => be_a(Hash),
      'prompts' => be_an(Array)
    }
  end

  before do
    enable_ai_catalog
  end

  describe 'constants' do
    it 'defines the correct chat flow type' do
      expect(described_class::CHAT_FLOW_TYPE).to eq('chat')
    end
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    shared_examples 'returns error response' do |expected_message|
      it 'returns an error service response' do
        result = execute

        expect(result).to be_error
        expect(result.message).to match_array(expected_message)
      end
    end

    context 'when user lack permission' do
      let(:current_user) { create(:user) }

      it_behaves_like 'returns error response', 'You have insufficient permissions'

      context 'when current_user is nil' do
        let(:current_user) { nil }

        it_behaves_like 'returns error response', 'You have insufficient permissions'
      end
    end

    context 'when wrapped_agent_response has error' do
      before do
        allow_next_instance_of(::Ai::Catalog::WrappedAgentFlowBuilder) do |builder|
          allow(builder).to receive(:execute).and_return(ServiceResponse.error(message: ['Generated flow is invalid']))
        end
      end

      it_behaves_like 'returns error response', 'Generated flow is invalid'
    end

    context 'when agent_version is nil' do
      let(:service_params) { super().merge({ agent_version: nil }) }

      it_behaves_like 'returns error response', 'Agent version is required'
    end

    context 'when flow_config_type is invalid' do
      let(:service_params) { super().merge({ flow_config_type: 'invalid_type' }) }

      it_behaves_like 'returns error response', 'Invalid value for flow_config_type. Only "chat" is supported.'
    end

    context 'when all parameters are valid' do
      let(:service_params) { super().merge({ flow_config_type: 'chat' }) }

      it 'generates valid YAML flow config with expected structure' do
        result = execute
        parsed_yaml = YAML.safe_load(result.payload[:flow_config])

        expect(result).to be_success
        expect(parsed_yaml).to include(json_config)

        prompts = parsed_yaml['prompts']

        prompt_component = prompts.first
        expect(prompt_component).to have_key('prompt_template')
        expect(prompt_component['prompt_template']).to have_key('system')
        expect(prompt_component['prompt_template']['system']).to eq(agent_version.def_system_prompt)
      end
    end
  end
end
