# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group(fullPath).ciQueueingHistory', :click_house, feature_category: :fleet_visibility do
  include GraphqlHelpers
  include RunnerReleasesHelper

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:runner) { create(:ci_runner, :group, :with_runner_manager, groups: [group]) }

  let_it_be(:maintainer) { create(:user) { |user| group.add_maintainer(user) } }
  let(:current_user) { maintainer }
  let(:required_license) { :runner_performance_insights_for_namespace }

  let_it_be(:starting_time) { Time.utc(2023) }
  let(:from_time) { starting_time }
  let(:to_time) { starting_time + 3.hours }

  let(:params) { { from_time: from_time, to_time: to_time } }
  let(:query_path) do
    [
      [:group, { full_path: group.full_path }],
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
    graphql_data_at(:group, :ci_queueing_history)
  end

  include_examples 'ciQueueingHistory'

  context 'when user is only a developer' do
    let(:current_user) { create(:user) { |user| group.add_developer(user) } }

    include_examples 'returns unauthorized error'
  end

  context 'when there are jobs belonging to other runners' do
    let(:instance_runner) { create(:ci_runner, :instance) }
    let(:project_runner) { create(:ci_runner, :project, projects: [project]) }
    let(:other_group) { create(:group) }
    let(:other_group_runner) { create(:ci_runner, :group, groups: [other_group]) }

    it 'filters jobs by runners belonging to this group' do
      builds = [
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time + 10.minutes,
          queued_at: starting_time + 10.minutes,
          started_at: starting_time + 10.minutes + 3.seconds,
          finished_at: starting_time + 11.minutes,
          runner: runner,
          runner_manager: runner.runner_managers.first),
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time,
          queued_at: starting_time,
          started_at: starting_time + 1.minute,
          finished_at: starting_time + 10.minutes,
          runner: project_runner,
          runner_manager: project_runner.runner_managers.first),
        build_stubbed(:ci_build,
          :success,
          created_at: starting_time,
          queued_at: starting_time,
          started_at: starting_time + 1.minute,
          finished_at: starting_time + 10.minutes,
          runner: other_group_runner,
          runner_manager: other_group_runner.runner_managers.first)
      ]

      insert_ci_builds_to_click_house(builds)

      expect(ci_queueing_history['timeSeries']).to eq([
        { 'p50' => 3, 'p75' => 3, 'p90' => 3, 'p95' => 3, 'p99' => 3,
          'time' => (starting_time + 10.minutes).utc.iso8601 }
      ])
    end
  end
end
