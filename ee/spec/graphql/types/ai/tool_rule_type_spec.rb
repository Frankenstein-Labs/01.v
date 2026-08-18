# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::ToolRuleType, feature_category: :ai_agents do
  include GraphqlHelpers

  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiToolRule')
  end

  it 'has the expected fields' do
    expected_fields = %w[id name action_type category source web_access local_access background_access]

    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
