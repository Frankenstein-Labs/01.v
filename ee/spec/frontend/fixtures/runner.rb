# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Runner EE (JavaScript fixtures)', feature_category: :fleet_visibility do
  include StubVersion
  include AdminModeHelper
  include ApiHelpers
  include JavaScriptFixturesHelpers
  include GraphqlHelpers
  include RunnerReleasesHelper

  let_it_be(:admin, freeze: false) { create(:admin) }

  query_path = 'ci/runner/graphql/'
  fixtures_path = 'graphql/ci/runner/'

  describe 'as admin', GraphQL::Query do
    before do
      sign_in(admin)
      enable_admin_mode!(admin)
    end

    describe 'all_runners.query.graphql', type: :request do
      all_runners_query = 'list/all_runners.query.graphql'
      let_it_be(:query, freeze: false) do
        get_graphql_query_as_string("#{query_path}#{all_runners_query}")
      end

      let_it_be(:upgrade_available_runner, freeze: false) { create(:ci_runner) }
      let_it_be(:upgrade_recommended_runner, freeze: false) { create(:ci_runner) }
      let_it_be(:up_to_date_runner, freeze: false) { create(:ci_runner) }

      before do
        stub_licensed_features(runner_upgrade_management: true)

        create(:ci_runner_version, version: '15.0.0', status: :available)
        create(:ci_runner_version, version: '15.1.0', status: :recommended)
        create(:ci_runner_version, version: '15.1.1', status: :unavailable)
        create(:ci_runner_machine, runner: upgrade_available_runner, version: '15.0.0')
        create(:ci_runner_machine, runner: upgrade_recommended_runner, version: '15.1.0')
        create(:ci_runner_machine, runner: up_to_date_runner, version: '15.1.1')
      end

      it "#{fixtures_path}#{all_runners_query}.upgrade_status.json" do
        post_graphql(query, current_user: admin, variables: {})

        expect_graphql_errors_to_be_empty
      end
    end

    describe 'most active runner', type: :request do
      let!(:build) { create(:ci_build, :picked, runner: runner) }
      let!(:build2) { create(:ci_build, :picked, runner: runner) }
      let!(:build3) { create(:ci_build, :picked, runner: runner2) }

      describe 'admin dashboard' do
        query_name = 'performance/most_active_runners.query.graphql'
        let_it_be(:query, freeze: false) do
          get_graphql_query_as_string("#{query_path}#{query_name}", ee: true)
        end

        let_it_be(:runner, freeze: false) { create(:ci_runner, :instance, description: 'Runner 1') }
        let_it_be(:runner2, freeze: false) { create(:ci_runner, :instance, description: 'Runner 2') }

        before do
          stub_licensed_features(runner_performance_insights: true)
        end

        it "#{fixtures_path}#{query_name}.json" do
          post_graphql(query, current_user: admin)

          expect_graphql_errors_to_be_empty
        end
      end

      describe 'group dashboard' do
        query_name = 'performance/group_most_active_runners.query.graphql'
        let_it_be(:query, freeze: false) do
          get_graphql_query_as_string("#{query_path}#{query_name}", ee: true)
        end

        let_it_be(:owner, freeze: false) { create(:user) }
        let_it_be(:group, freeze: false) { create(:group, owners: owner) }
        let_it_be(:runner, freeze: false) { create(:ci_runner, :group, groups: [group], description: 'Runner 1') }
        let_it_be(:runner2, freeze: false) { create(:ci_runner, :group, groups: [group], description: 'Runner 2') }

        before do
          stub_licensed_features(runner_performance_insights_for_namespace: [group])
        end

        it "#{fixtures_path}#{query_name}.json" do
          post_graphql(query, current_user: owner, variables: { fullPath: group.full_path })

          expect_graphql_errors_to_be_empty
        end
      end
    end

    describe 'runner_failed_jobs.graphql', type: :request do
      query_name = 'performance/runner_failed_jobs.graphql'

      let(:query) do
        get_graphql_query_as_string("#{query_path}#{query_name}", ee: true)
      end

      let(:runner) { create(:ci_runner, :instance, description: 'Runner 1') }
      let(:build) do
        create(:ci_build, :failed, :trace_live, runner: runner, failure_reason: :runner_system_failure)
      end

      let(:build2) do
        create(:ci_build, :failed, :trace_live, runner: runner, failure_reason: :runner_system_failure)
      end

      before do
        stub_licensed_features(runner_performance_insights: true)
        stub_application_setting(ci_job_live_trace_enabled: true)
        build
        build2

        Ci::Build.all.find_each { |build| ::Ci::InstanceRunnerFailedJobs.track(build) }
      end

      it "#{fixtures_path}#{query_name}.json", :aggregate_failures do
        post_graphql(query, current_user: admin)

        expect_graphql_errors_to_be_empty
        expect(graphql_data_at(:jobs, :nodes)).to contain_exactly(
          a_graphql_entity_for(build),
          a_graphql_entity_for(build2)
        )
      end
    end
  end
end
