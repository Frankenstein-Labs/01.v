# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::FoundationalChatAgentFlowConfigType, feature_category: :duo_agent_platform do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiFoundationalChatAgentFlowConfig')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      flow_config_id
      flow_config_schema_version
      flow_version
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
