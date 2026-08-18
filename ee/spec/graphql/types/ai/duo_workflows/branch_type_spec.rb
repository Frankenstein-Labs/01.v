# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::DuoWorkflows::BranchType, feature_category: :duo_agent_platform do
  subject(:fields) { described_class.fields }

  it { expect(described_class.graphql_name).to eq('DuoWorkflowBranch') }

  it 'includes the expected fields' do
    expect(described_class).to have_graphql_fields(:fork_thread_ts, :messages)
  end

  it 'exposes the fork point as a nullable string' do
    expect(fields['forkThreadTs']).to have_nullable_graphql_type(GraphQL::Types::String)
  end

  it 'exposes messages as the same type the checkpoint reads use' do
    expect(fields['messages'].type.of_type.of_type.of_type).to eq(Types::Ai::DuoWorkflows::DuoMessageType)
  end

  it 'includes the expected scopes' do
    %w[forkThreadTs messages].each do |field_name|
      expect(fields[field_name].instance_variable_get(:@scopes))
        .to include(:api, :read_api, :ai_features, :ai_workflows)
    end
  end
end
