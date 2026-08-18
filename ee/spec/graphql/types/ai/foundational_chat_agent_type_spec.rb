# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::FoundationalChatAgentType, feature_category: :duo_agent_platform do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiFoundationalChatAgent')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      avatar_url
      description
      flow_config
      id
      name
      reference
      reference_with_version
      selectable_in_chat
      system_prompt
      tools
      version
    ]

    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
