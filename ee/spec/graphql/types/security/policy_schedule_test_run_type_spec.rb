# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PolicyScheduleTestRun'], feature_category: :security_policy_management do
  it { expect(described_class.graphql_name).to eq('PolicyScheduleTestRun') }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :state,
      :started_at,
      :finished_at,
      :duration,
      :error_message,
      :project,
      :created_at,
      :pipeline,
      :completed
    )
  end

  specify { expect(described_class).to require_graphql_authorizations(:read_policy_schedule_test_run) }
end
