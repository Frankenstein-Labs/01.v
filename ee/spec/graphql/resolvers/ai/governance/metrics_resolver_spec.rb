# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::Governance::MetricsResolver, feature_category: :compliance_management do
  include GraphqlHelpers

  it 'has the correct nullable graphql type' do
    expect(described_class).to have_nullable_graphql_type(Types::Ai::Governance::MetricsType)
  end

  it 'has the expected arguments' do
    expect(described_class).to have_graphql_arguments(:timeframe, :agent_class)
  end

  it 'defines the timeframe argument as optional with the expected type and default' do
    argument = described_class.arguments['timeframe']

    expect(argument.type).to eq(Types::Ai::Governance::MetricsTimeframeEnum)
    expect(argument.default_value).to eq(:last_7_days)
  end

  it 'defines the agent_class argument as optional with the expected type and default' do
    argument = described_class.arguments['agentClass']

    expect(argument.type).to eq(Types::Ai::Governance::AgentClassEnum)
    expect(argument.default_value).to eq(:all)
  end

  it 'authorizes read_agent_artifacts' do
    expect(described_class).to require_graphql_authorizations(:read_agent_artifacts)
  end
end
