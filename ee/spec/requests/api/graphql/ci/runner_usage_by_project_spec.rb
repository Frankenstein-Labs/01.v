# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.ciRunnerUsageByProject', :click_house, feature_category: :fleet_visibility do
  include GraphqlHelpers

  let_it_be(:group1) { create(:group) }
  let_it_be(:projects) { create_list(:project, 7, group: group1) }
  let_it_be(:project) { projects.first }
  let_it_be(:instance_runner) { create(:ci_runner, :instance) }
  let_it_be(:project_runner) { create(:ci_runner, :project, projects: [project]) }

  let_it_be(:admin) { create(:user, :admin) }
  let_it_be(:group_maintainer) { create(:user, maintainer_of: group1) }
  let_it_be(:group_developer) { create(:user, developer_of: group1) }
  let_it_be(:starting_date) { Date.new(2023) }

  let(:full_path) { nil }
  let(:runner_type) { nil }
  let(:from_date) { starting_date }
  let(:to_date) { starting_date + 1.day }
  let(:projects_limit) { nil }

  let(:params) do
    {
      full_path: full_path, runner_type: runner_type, from_date: from_date, to_date: to_date,
      projects_limit: projects_limit
    }.compact
  end

  let(:query_path) do
    [
      [:runner_usage_by_project, params]
    ]
  end

  let(:query_node) do
    <<~QUERY
      project {
        id
        name
        fullPath
      }
      ciDuration
      ciMinutesUsed
      ciBuildCount
    QUERY
  end

  let(:current_user) { admin }

  let(:query) do
    graphql_query_for('runnerUsageByProject', params, query_node)
  end

  let(:execute_query) do
    post_graphql(query, current_user: current_user)
  end

  let(:licensed_feature_available) { true }

  subject(:runner_usage_by_project) do
    execute_query
    graphql_data_at(:runner_usage_by_project)
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

  context "when service returns an error" do
    before do
      allow_next_instance_of(::Ci::Runners::GetUsageByProjectService) do |service|
        allow(service).to receive(:execute).and_return(ServiceResponse.error(message: 'error 123'))
      end
    end

    it 'returns this error' do
      execute_query

      expect_graphql_errors_to_include("error 123")
    end
  end

  it 'returns empty runner_usage_by_project with no data' do
    expect(runner_usage_by_project).to eq([])
  end

  shared_examples 'returns top N projects' do |n|
    let(:top_projects) { projects.first(n) }
    let(:other_projects) { projects - top_projects }

    it "returns #{n} projects consuming most of the runner minutes and one line for the 'rest'" do
      builds = top_projects.flat_map.with_index(1) do |project, index|
        Array.new(index) do
          stubbed_build(starting_date, 20.minutes, project: project, runner: default_runner)
        end
      end

      builds += other_projects.flat_map do |project|
        Array.new(3) do
          stubbed_build(starting_date, 2.minutes, project: project, runner: default_runner)
        end
      end

      insert_ci_builds_to_click_house(builds)

      expected_result = top_projects.flat_map.with_index(1) do |project, index|
        {
          'project' => a_graphql_entity_for(project, :name, :full_path),
          'ciDuration' => (20 * index).to_s,
          'ciMinutesUsed' => (20 * index).to_s,
          'ciBuildCount' => index.to_s
        }
      end.reverse + [{
        'project' => nil,
        'ciDuration' => (other_projects.count * 3 * 2).to_s,
        'ciMinutesUsed' => (other_projects.count * 3 * 2).to_s,
        'ciBuildCount' => (other_projects.count * 3).to_s
      }]

      expect(runner_usage_by_project).to match(expected_result)
    end
  end

  shared_examples 'a working ciRunnerUsageByProject query' do
    context "when runner_performance_insights feature is disabled" do
      let(:licensed_feature_available) { false }

      include_examples "returns unauthorized or unavailable error"
    end

    it 'only counts builds from from_date to to_date' do
      builds = [from_date - 1.minute, from_date, to_date + 1.day - 1.minute, to_date + 1.day]
        .map.with_index(1) do |finished_at, index|
          stubbed_build(finished_at, index.minutes, runner: default_runner)
        end
      insert_ci_builds_to_click_house(builds)

      expect(runner_usage_by_project).to contain_exactly({
        'project' => a_graphql_entity_for(project, :name, :full_path),
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
        ].map.with_index(1) do |finished_at, index|
          stubbed_build(finished_at, index.minutes, runner: default_runner)
        end
        insert_ci_builds_to_click_house(builds)

        execute_query
        expect_graphql_errors_to_be_empty

        expect(runner_usage_by_project).to contain_exactly({
          'project' => a_graphql_entity_for(project, :name, :full_path),
          'ciDuration' => '5',
          'ciMinutesUsed' => '5',
          'ciBuildCount' => '2'
        })
      end
    end

    context 'when runner_type is specified' do
      let(:runner_type) { :PROJECT_TYPE }

      it 'filters data by runner type' do
        builds = [
          stubbed_build(starting_date, 21.minutes, runner: default_runner),
          stubbed_build(starting_date, 33.minutes, runner: project_runner)
        ]

        insert_ci_builds_to_click_house(builds)

        expect(runner_usage_by_project).to contain_exactly({
          'project' => a_graphql_entity_for(project, :name, :full_path),
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
    let(:default_runner) { instance_runner }

    it_behaves_like 'a working ciRunnerUsageByProject query'

    include_examples 'returns top N projects', 5

    context 'when projects_limit = 2' do
      let(:projects_limit) { 2 }

      include_examples 'returns top N projects', 2
    end

    context 'when projects_limit > MAX_PROJECTS_LIMIT' do
      let(:projects_limit) { 5 }

      before do
        stub_const('Resolvers::Ci::RunnerUsageByProjectResolver::MAX_PROJECTS_LIMIT', 3)
      end

      include_examples 'returns top N projects', 3
    end
  end

  context 'when fullPath is specified' do
    let(:full_path) { group1.full_path }
    let(:current_user) { group_maintainer }

    before do
      stub_licensed_features(runner_performance_insights_for_namespace: licensed_feature_available)
    end

    context 'and fullPath refers to a group' do
      let_it_be(:group1_runner) { create(:ci_runner, :group, groups: [group1]) }

      let(:full_path) { group1.full_path }
      let(:default_runner) { group1_runner }

      it_behaves_like 'a working ciRunnerUsageByProject query'

      include_examples 'returns top N projects', 5

      context 'when projects_limit = 2' do
        let(:projects_limit) { 2 }

        include_examples 'returns top N projects', 2
      end

      context 'when projects_limit > MAX_PROJECTS_LIMIT' do
        let(:projects_limit) { 5 }

        before do
          stub_const('Resolvers::Ci::RunnerUsageByProjectResolver::MAX_PROJECTS_LIMIT', 3)
        end

        include_examples 'returns top N projects', 3
      end

      context 'when multiple groups exist' do
        let_it_be(:group2) { create(:group, maintainers: group_maintainer) }
        let_it_be(:project2) { create(:project, group: group2) }

        before do
          group2_runner = create(:ci_runner, :group, groups: [group2])
          builds = [
            stubbed_build(1.hour.after(starting_date), 21.minutes, runner: group1_runner, project: project),
            stubbed_build(10.hours.after(starting_date), 33.minutes, runner: group2_runner, project: project2)
          ]

          insert_ci_builds_to_click_house(builds)
        end

        context 'when full_path refers to group1' do
          let(:full_path) { group1.full_path }

          it "returns only group's projects" do
            expect(runner_usage_by_project).to contain_exactly({
              'project' => a_graphql_entity_for(project, :name, :full_path),
              'ciDuration' => '21',
              'ciMinutesUsed' => '21',
              'ciBuildCount' => '1'
            })
          end
        end

        context 'when full_path refers to group2' do
          let(:full_path) { group2.full_path }

          it "returns only group2's projects" do
            expect(runner_usage_by_project).to contain_exactly({
              'project' => a_graphql_entity_for(project2, :name, :full_path),
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
      let(:full_path) { project.full_path }
      let(:default_runner) { instance_runner }

      it_behaves_like 'a working ciRunnerUsageByProject query'

      context 'when multiple projects exist' do
        let_it_be(:project2) { projects.second }
        let_it_be(:project2_runner) { create(:ci_runner, :project, projects: [project2]) }

        before do
          builds = [
            stubbed_build(1.hour.after(starting_date), 21.minutes, runner: project_runner, project: project),
            stubbed_build(10.hours.after(starting_date), 33.minutes, runner: project2_runner, project: project2)
          ]

          insert_ci_builds_to_click_house(builds)
        end

        context 'when full_path refers to project' do
          let(:full_path) { project.full_path }

          it "returns only stats referring to project" do
            expect(runner_usage_by_project).to contain_exactly({
              'project' => a_graphql_entity_for(project, :name, :full_path),
              'ciDuration' => '21',
              'ciMinutesUsed' => '21',
              'ciBuildCount' => '1'
            })
          end
        end

        context 'when full_path refers to project2' do
          let(:full_path) { project2.full_path }

          it "returns only stats referring to project2" do
            expect(runner_usage_by_project).to contain_exactly({
              'project' => a_graphql_entity_for(project2, :name, :full_path),
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

  def stubbed_build(finished_at, duration, runner:, project: projects.first)
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
