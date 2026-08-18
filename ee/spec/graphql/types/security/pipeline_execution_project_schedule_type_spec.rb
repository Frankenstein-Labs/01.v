# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PipelineExecutionProjectSchedule'], feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:policy_project) { create(:project) }
  let_it_be(:user) { create(:user, developer_of: policy_project) }
  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: policy_project)
  end

  let_it_be(:policy) do
    create(:security_policy, :pipeline_execution_schedule_policy,
      security_orchestration_policy_configuration: policy_configuration)
  end

  let_it_be(:schedule) do
    create(:security_pipeline_execution_project_schedule,
      security_policy: policy,
      cron_timezone: 'America/New_York')
  end

  it { expect(described_class.graphql_name).to eq('PipelineExecutionProjectSchedule') }

  it 'has the expected fields' do
    expect(described_class).to have_graphql_fields(
      :id,
      :project,
      :next_run_at,
      :cron,
      :cron_timezone,
      :time_window_seconds,
      :snoozed_until
    )
  end

  specify { expect(described_class).to require_graphql_authorizations(:read_pipeline_execution_project_schedule) }

  describe '#next_run_at' do
    it 'returns the next_run_at in the schedule timezone' do
      result = resolve_field(:next_run_at, schedule, current_user: user)

      expect(result.time_zone.name).to eq('America/New_York')
    end

    context 'when next_run_at is nil' do
      before do
        allow(schedule).to receive(:next_run_at).and_return(nil)
      end

      it 'returns nil' do
        expect(resolve_field(:next_run_at, schedule, current_user: user)).to be_nil
      end
    end
  end
end
