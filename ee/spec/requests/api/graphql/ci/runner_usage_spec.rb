# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.ciRunnerUsage', :click_house, feature_category: :fleet_visibility do
  include GraphqlHelpers

  let_it_be(:instance_runners) { create_list(:ci_runner, 7, :instance) }
  let_it_be(:group1) { create(:group) }
  let_it_be(:project1) { create(:project, group: group1) }
  let_it_be(:project2) { create(:project, group: group1) }
  let_it_be(:group1_runners) { create_list(:ci_runner, 2, :group, groups: [group1]) }

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:group_maintainer) { create(:user, maintainer_of: group1) }
  let_it_be(:group_developer) { create(:user, developer_of: group1) }
  let_it_be(:starting_date) { Date.new(2023) }

  let(:full_path) { nil }
  let(:runner_type) { nil }
  let(:from_date) { starting_date }
  let(:to_date) { starting_date + 1.day }
  let(:runners_limit) { nil }

  let(:params) do
    {
      full_path: full_path, runner_type: runner_type, from_date: from_date, to_date: to_date,
      runners_limit: runners_limit
    }.compact
  end

  let(:query_path) do
    [
      [:runner_usage, params]
    ]
  end

  let(:query_node) do
    <<~QUERY
      runner {
        id
        description
      }
      ciDuration
      ciMinutesUsed
      ciBuildCount
    QUERY
  end

  let(:current_user) { admin }

  let(:query) do
    graphql_query_for('runnerUsage', params, query_node)
  end

  let(:execute_query) do
    post_graphql(query, current_user: current_user)
  end

  let(:licensed_feature_available) { true }

  subject(:runner_usage) do
    execute_query
    graphql_data_at(:runner_usage)
  end

  before do
    stub_licensed_features(runner_performance_insights: licensed_feature_available)
  end

  shared_examples "returns unauthorized or unavailable error" do
    it 'returns error' do
      execute_query

      expect_graphql_errors_to_include("The resource that you are attempting to access does not exist " \
                                       "or you don't have permission to perform this action")
    end
  end

  context "when ClickHouse database is not configured" do
    before do
      allow(ClickHouse::Client).to receive(:database_configured?).and_return(false)
    end

    include_examples "returns unauthorized or unavailable error"
  end

  context "when user is nil" do
    let(:current_user) { nil }

    include_examples "returns unauthorized or unavailable error"
  end

  context "when user is not admin" do
    let(:current_user) { group_developer }

    include_examples "returns unauthorized or unavailable error"
  end

  shared_examples 'returns top N runners' do |n|
    let(:top_runners) { instance_runners.first(n) }
    let(:other_runners) { instance_runners - top_runners }

    it "returns #{n} runners executed most of the compute minutes and one line for the 'rest'" do
      builds = top_runners.flat_map.with_index(1) do |runner, index|
        Array.new(index) do
          stubbed_build(starting_date, 20.minutes, runner: runner)
        end
      end

      builds += other_runners.flat_map do |runner|
        Array.new(3) do
          stubbed_build(starting_date, 2.minutes, runner: runner)
        end
      end

      insert_ci_builds_to_click_house(builds)

      expected_result = top_runners.flat_map.with_index(1) do |runner, index|
        {
          'runner' => a_graphql_entity_for(runner, :description),
          'ciDuration' => (20 * index).to_s,
          'ciMinutesUsed' => (20 * index).to_s,
          'ciBuildCount' => index.to_s
        }
      end.reverse + [
        {
          'runner' => nil,
          'ciDuration' => (other_runners.count * 3 * 2).to_s,
          'ciMinutesUsed' => (other_runners.count * 3 * 2).to_s,
          'ciBuildCount' => (other_runners.count * 3).to_s
        }
      ]

      expect(runner_usage).to match(expected_result)
    end
  end

  shared_examples 'a working ciRunnerUsage query' do
    context "when runner_performance_insights feature is disabled" do
      let(:licensed_feature_available) { false }

      include_examples "returns unauthorized or unavailable error"
    end

    context "when service returns an error" do
      before do
        allow_next_instance_of(::Ci::Runners::GetUsageService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error 123'))
        end
      end

      it 'returns this error' do
        execute_query

        expect_graphql_errors_to_include("error 123")
      end
    end

    it 'returns empty runner_usage with no data' do
      expect(runner_usage).to eq([])
    end

    it 'only counts builds from from_date to to_date' do
      builds = [from_date - 1.minute, from_date, to_date + 1.day - 1.minute, to_date + 1.day]
        .map.with_index(1) do |finished_at, index|
          stubbed_build(finished_at, index.minutes)
        end
      insert_ci_builds_to_click_house(builds)

      expect(runner_usage).to contain_exactly({
        'runner' => a_graphql_entity_for(instance_runners.first, :description),
        'ciDuration' => '5',
        'ciMinutesUsed' => '5',
        'ciBuildCount' => '2'
      })
    end

    context 'when from_date and to_date are not specified' do
      let(:from_date) { nil }
      let(:to_date) { nil }

      around do |example|
        travel_to(Date.new(2024, 2, 1)) do
          example.run
        end
      end

      it 'defaults time frame to the last calendar month' do
        from_date_default = Date.new(2024, 1, 1)
        to_date_default = Date.new(2024, 1, 31)

        builds = [
          from_date_default - 1.minute,
          from_date_default,
          to_date_default + 1.day - 1.minute,
          to_date_default + 1.day
        ].map.with_index(1) { |finished_at, index| stubbed_build(finished_at, index.minutes) }
        insert_ci_builds_to_click_house(builds)

        expect(runner_usage).to contain_exactly({
          'runner' => a_graphql_entity_for(instance_runners.first, :description),
          'ciDuration' => '5',
          'ciMinutesUsed' => '5',
          'ciBuildCount' => '2'
        })
      end
    end

    context 'when runner_type is specified' do
      let(:runner_type) { :GROUP_TYPE }

      it 'filters data by runner type' do
        builds = [
          stubbed_build(starting_date, 21.minutes),
          stubbed_build(starting_date, 33.minutes, runner: group1_runners.first)
        ]

        insert_ci_builds_to_click_house(builds)

        expect(runner_usage).to contain_exactly({
          'runner' => a_graphql_entity_for(group1_runners.first, :description),
          'ciDuration' => '33',
          'ciMinutesUsed' => '33',
          'ciBuildCount' => '1'
        })
      end
    end

    context 'when requesting more than 1 year' do
      let(:to_date) { from_date + 13.months }

      it 'returns error' do
        execute_query

        expect_graphql_errors_to_include("'to_date' must be greater than 'from_date' and be within 1 year")
      end
    end

    context 'when to_date is before from_date' do
      let(:to_date) { from_date - 1.day }

      it 'returns error' do
        execute_query

        expect_graphql_errors_to_include("'to_date' must be greater than 'from_date' and be within 1 year")
      end
    end
  end

  context 'when fullPath is not specified' do
    let(:full_path) { nil }

    context 'when user is admin' do
      let(:current_user) { admin }

      it_behaves_like 'a working ciRunnerUsage query'

      include_examples 'returns top N runners', 5

      context 'when runners_limit = 2' do
        let(:runners_limit) { 2 }

        include_examples 'returns top N runners', 2
      end

      context 'when runners_limit > MAX_RUNNERS_LIMIT' do
        let(:runners_limit) { 5 }

        before do
          stub_const('Resolvers::Ci::RunnerUsageResolver::MAX_RUNNERS_LIMIT', 3)
        end

        include_examples 'returns top N runners', 3
      end
    end
  end

  context 'when fullPath is specified' do
    let(:current_user) { group_maintainer }
    let(:full_path) { specified_context.full_path }

    before do
      stub_licensed_features(runner_performance_insights_for_namespace: licensed_feature_available)
    end

    context 'and fullPath refers to a group' do
      let(:specified_context) { group1 }

      it_behaves_like 'a working ciRunnerUsage query'

      context "and fullPath doesn't match case" do
        let(:full_path) { specified_context.full_path.upcase }

        it_behaves_like 'a working ciRunnerUsage query'
      end

      context 'when multiple runners exist' do
        let_it_be(:group2) { create(:group, maintainers: group_maintainer) }
        let_it_be(:group2_runner) { create(:ci_runner, :group, groups: [group2]) }
        let_it_be(:group2_project) { create(:project, group: group2) }

        before do
          builds = [
            stubbed_build(1.hour.after(starting_date), 21.minutes, runner: group1_runners.first, project: project1),
            stubbed_build(10.hours.after(starting_date), 33.minutes, runner: group2_runner, project: group2_project)
          ]

          insert_ci_builds_to_click_house(builds)
        end

        context 'when specified context is group1' do
          let(:specified_context) { group1 }

          it "returns only group1's runners" do
            expect(runner_usage).to contain_exactly({
              'runner' => a_graphql_entity_for(group1_runners.first, :description),
              'ciDuration' => '21',
              'ciMinutesUsed' => '21',
              'ciBuildCount' => '1'
            })
          end
        end

        context 'when specified context is group2' do
          let(:specified_context) { group2 }

          it "returns only group2's runners" do
            expect(runner_usage).to contain_exactly({
              'runner' => a_graphql_entity_for(group2_runner, :description),
              'ciDuration' => '33',
              'ciMinutesUsed' => '33',
              'ciBuildCount' => '1'
            })
          end
        end
      end

      context 'when specified group is not accessible' do
        let(:current_user) { group_developer }

        include_examples 'returns unauthorized or unavailable error'
      end
    end

    context 'and fullPath refers to a project' do
      let(:specified_context) { project1 }

      it_behaves_like 'a working ciRunnerUsage query'

      include_examples 'returns top N runners', 5

      context 'when runners_limit = 2' do
        let(:runners_limit) { 2 }

        include_examples 'returns top N runners', 2
      end

      context 'when runners_limit > MAX_RUNNERS_LIMIT' do
        let(:runners_limit) { 5 }

        before do
          stub_const('Resolvers::Ci::RunnerUsageResolver::MAX_RUNNERS_LIMIT', 3)
        end

        include_examples 'returns top N runners', 3
      end

      context "and fullPath doesn't match case" do
        let(:full_path) { specified_context.full_path.upcase }

        it_behaves_like 'a working ciRunnerUsage query'
      end

      context 'when multiple runners exist' do
        before do
          builds = [
            stubbed_build(1.hour.after(starting_date), 21.minutes, runner: group1_runners.first, project: project1),
            stubbed_build(10.hours.after(starting_date), 33.minutes, runner: group1_runners.second, project: project2)
          ]

          insert_ci_builds_to_click_house(builds)
        end

        context 'when specified context is project1' do
          let(:specified_context) { project1 }

          it "returns only stats referring to project" do
            expect(runner_usage).to contain_exactly({
              'runner' => a_graphql_entity_for(group1_runners.first, :description),
              'ciDuration' => '21',
              'ciMinutesUsed' => '21',
              'ciBuildCount' => '1'
            })
          end
        end

        context 'when specified context is project2' do
          let(:specified_context) { project2 }

          it "returns only stats referring to project2" do
            expect(runner_usage).to contain_exactly({
              'runner' => a_graphql_entity_for(group1_runners.second, :description),
              'ciDuration' => '33',
              'ciMinutesUsed' => '33',
              'ciBuildCount' => '1'
            })
          end
        end
      end

      context 'when specified project is not accessible' do
        let(:current_user) { group_developer }

        include_examples 'returns unauthorized or unavailable error'
      end
    end
  end

  def stubbed_build(finished_at, duration, runner: instance_runners.first, project: project1)
    created_at = finished_at - duration

    build_stubbed(:ci_build,
      :success,
      project: project,
      created_at: created_at,
      queued_at: created_at,
      started_at: created_at,
      finished_at: finished_at,
      runner: runner)
  end
end
