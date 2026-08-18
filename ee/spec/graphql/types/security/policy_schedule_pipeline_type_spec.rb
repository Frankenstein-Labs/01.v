# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicySchedulePipeline'], feature_category: :security_policy_management do
  it { expect(described_class.graphql_name).to eq('PolicySchedulePipeline') }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :created_at,
      :pipeline,
      :project
    )
  end

  specify { expect(described_class).to require_graphql_authorizations(:read_policy_schedule_pipeline) }
end
