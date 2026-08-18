# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::BulkToolRuleInputType, feature_category: :ai_agents do
  include GraphqlHelpers

  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('BulkToolRuleInput')
  end

  it 'has the expected arguments' do
    expected_arguments = %w[tool_id web_access local_access background_access]
    expect(described_class).to have_graphql_arguments(*expected_arguments)
  end
end
