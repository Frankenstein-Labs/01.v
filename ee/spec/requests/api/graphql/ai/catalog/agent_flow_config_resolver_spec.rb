# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting AI catalog agent flow configuration', :with_current_organization, :aggregate_failures, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, guests: user) }
  let_it_be_with_reload(:agent) { create(:ai_catalog_agent, project: project) }
  let_it_be_with_reload(:agent_version) { create(:ai_catalog_agent_version, item: agent) }

  let(:current_user) { user }
  let(:agent_version_gid) { agent_version.to_global_id }
  let(:chat_flow_type) { :CHAT }
  let(:args) { { agentVersionId: agent_version_gid, flowConfigType: chat_flow_type } }

  let(:query) do
    graphql_query_for('aiCatalogAgentFlowConfig', args)
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

  shared_examples 'returns valid flow configuration' do
    it 'returns valid flow configuration with expected structure' do
      post_graphql(query, current_user: current_user)

      flow_config = graphql_data_at(:ai_catalog_agent_flow_config)
      parsed_yaml = YAML.safe_load(flow_config)

      expect(response).to have_gitlab_http_status(:success)
      expect(parsed_yaml).to include(json_config)

      prompts = parsed_yaml['prompts']

      prompt_component = prompts.first
      expect(prompt_component).to have_key('prompt_template')
      expect(prompt_component['prompt_template']).to have_key('system')
      expect(prompt_component['prompt_template']['system']).to eq(agent_version.def_system_prompt)
    end
  end

  shared_examples 'when request fails' do
    it 'returns nil flow config' do
      post_graphql(query, current_user: current_user)

      flow_config_data = graphql_data_at(:ai_catalog_agent_flow_config)

      expect(flow_config_data).to be_nil
    end
  end

  it_behaves_like 'returns valid flow configuration'

  context 'when passing specific agent_version_id' do
    let(:agent_definition) do
      {
        'system_prompt' => 'Talk like software engineer',
        'user_prompt' => 'What is a leap year?',
        'tools' => []
      }
    end

    let(:another_agent_version) do
      create(:ai_catalog_agent_version, item: agent, definition: agent_definition, version: '2.1.0')
    end

    let(:agent_version) { another_agent_version }

    let(:args) do
      { flowConfigType: chat_flow_type, agentVersionId: agent_version.to_global_id }
    end

    it_behaves_like 'returns valid flow configuration'
  end

  context 'when WrappedAgentFlowBuilder returns error' do
    let(:wrapped_agent_flow_builder) { instance_double(Ai::Catalog::WrappedAgentFlowBuilder) }
    let(:error_messages) { ['Build error'] }
    let(:error_response) { ServiceResponse.error(message: error_messages) }

    before do
      allow(Ai::Catalog::WrappedAgentFlowBuilder).to receive(:new)
        .and_return(wrapped_agent_flow_builder)
      allow(wrapped_agent_flow_builder).to receive(:execute).and_return(error_response)
    end

    it_behaves_like 'when request fails'
  end

  context 'with an anonymous user' do
    let(:current_user) { nil }

    it_behaves_like 'when request fails'
  end

  context 'when agent belongs to different organization' do
    let_it_be(:different_organization) { create(:organization) }
    let_it_be_with_reload(:different_agent) { create(:ai_catalog_agent, organization: different_organization) }
    let_it_be_with_reload(:different_agent_version) { create(:ai_catalog_agent_version, item: different_agent) }
    let(:agent_version_gid) { different_agent_version.to_global_id }

    it_behaves_like 'when request fails'
  end

  context 'with an invalid agent_version_id' do
    let(:agent_version_gid) { "gid://gitlab/Ai::Catalog::ItemVersion/#{non_existing_record_id}" }

    it_behaves_like 'when request fails'
  end
end
