# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.ciQueueingHistory', :click_house, feature_category: :fleet_visibility do
  include GraphqlHelpers
  include RunnerReleasesHelper

  let_it_be(:project) { create(:project) }
  let_it_be(:instance_runner) { create(:ci_runner, :instance, :with_runner_manager) }
  let_it_be(:project_runner) { create(:ci_runner, :project, :with_runner_manager, projects: [project]) }

  let_it_be(:admin) { create(:user, :admin) }
  let(:current_user) { admin }
  let(:required_license) { :runner_performance_insights }

  let(:runner_type) { nil }

  let_it_be(:starting_time) { Time.utc(2023) }
  let(:from_time) { starting_time }
  let(:to_time) { starting_time + 3.hours }

  let(:params) { { runner_type: runner_type, from_time: from_time, to_time: to_time } }
  let(:query_path) do
    [
      [:ci_queueing_history, params],
      :time_series
    ]
  end

  let(:query) do
    wrap_fields(query_graphql_path(query_path, 'time p50 p75 p90 p95 p99'))
  end

  let(:execute_query) do
    post_graphql(query, current_user: current_user)
  end

  subject(:ci_queueing_history) do
    execute_query
    graphql_data_at(:ci_queueing_history)
  end

  include_examples 'ciQueueingHistory' do
    let(:runner) { instance_runner }
  end

  context 'when user is not admin' do
    let(:current_user) { create(:user) }

    include_examples 'returns unauthorized error'
  end

  context 'when runner_type is specified' do
    let(:runner_type) { :PROJECT_TYPE }

    it 'filters data by runner type' do
      builds = [
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time,
          queued_at: starting_time,
          started_at: starting_time + 1.minute,
          finished_at: starting_time + 10.minutes,
          runner: instance_runner,
          runner_manager: instance_runner.runner_managers.first),
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time + 10.minutes,
          queued_at: starting_time + 10.minutes,
          started_at: starting_time + 10.minutes + 3.seconds,
          finished_at: starting_time + 11.minutes,
          runner: project_runner,
          runner_manager: project_runner.runner_managers.first)
      ]

      insert_ci_builds_to_click_house(builds)

      expect(ci_queueing_history['timeSeries']).to eq([
        { 'p50' => 3, 'p75' => 3, 'p90' => 3, 'p95' => 3, 'p99' => 3,
          'time' => (starting_time + 10.minutes).utc.iso8601 }
      ])
    end
  end
end
