# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::DuoWorkflows::CheckpointWriteType, feature_category: :duo_agent_platform do
  subject(:fields) { described_class.fields }

  it 'includes the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :thread_ts,
      :task,
      :idx,
      :channel,
      :write_type,
      :data
    )
  end

  it 'includes expected scopes for each field' do
    fields.each_key do |field_name|
      expect(fields[field_name].instance_variable_get(:@scopes))
        .to include(:api, :read_api, :ai_features, :ai_workflows)
    end
  end
end
