# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::FlowCapabilityType, feature_category: :duo_agent_platform do
  include GraphqlHelpers

  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiFlowCapability')
  end

  it 'has the expected fields' do
    expected_fields = %w[name metadata]
    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
