# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.runner(id)', feature_category: :fleet_visibility do
  include GraphqlHelpers
  include RunnerReleasesHelper

  # NOTE: No cross-organization isolation test for the single-runner lookup path (`Query.runner(id)`).
  # It resolves a specific runner by global ID and authorizes by the requesting user's permission on
  # that runner rather than scoping a collection by hierarchy, so there is no organization boundary to
  # assert here. The examples below are exercised by admins (or custom admin roles), which is the
  # cell-scoped admin path: admins see every runner on the cell, across all organizations.
  let_it_be(:admin) { create(:user, :admin) }

  describe 'upgradeStatus', :saas do
    let_it_be(:runner) { create(:ci_runner, description: 'Runner 1') }

    shared_examples 'runner details fetch operation returning expected upgradeStatus' do
      let(:query) do
        managers_path = query_graphql_path(%i[managers nodes], 'id upgradeStatus')

        wrap_fields(query_graphql_path(query_path, "id upgradeStatus #{managers_path}"))
      end

      let(:query_path) do
        [
          [:runner, { id: runner.to_global_id.to_s }]
        ]
      end

      it 'retrieves expected fields' do
        post_graphql(query, current_user: current_user)

        runner_data = graphql_data_at(:runner)

        expect(runner_data).not_to be_nil
        expect(runner_data).to match a_graphql_entity_for(runner, upgrade_status: expected_upgrade_status)
        expect(graphql_dig_at(runner_data, :managers, :nodes)).to match [
          a_graphql_entity_for(runner_manager1, upgrade_status: expected_manager1_upgrade_status),
          a_graphql_entity_for(runner_manager2, upgrade_status: expected_manager2_upgrade_status)
        ]
      end

      context 'when fetching runner releases is disabled' do
        before do
          stub_application_setting(update_runner_versions_enabled: false)
        end

        it 'retrieves runner data with nil upgrade status' do
          post_graphql(query, current_user: current_user)

          runner_data = graphql_data_at(:runner)

          expect(runner_data).not_to be_nil
          expect(runner_data).to match a_graphql_entity_for(runner, upgrade_status: nil)
        end
      end
    end

    context 'with runner with 2 runner managers' do
      let_it_be(:runner_manager2) do
        create(:ci_runner_machine, runner: runner, version: '14.0.0', revision: 'a')
      end

      let_it_be(:runner_manager1) do
        create(:ci_runner_machine, runner: runner, version: '14.1.0', revision: 'b')
      end

      let!(:manager1_version) do
        create(:ci_runner_version, version: runner_manager1.version, status: db_version_status(manager1_version_status))
      end

      let!(:manager2_version) do
        create(:ci_runner_version, version: runner_manager2.version, status: db_version_status(manager2_version_status))
      end

      let(:manager1_version_status) { nil }
      let(:manager2_version_status) { nil }

      def db_version_status(status)
        status == :error ? nil : status
      end

      context 'with mocked RunnerUpgradeCheck' do
        using RSpec::Parameterized::TableSyntax

        before do
          # Set up stubs for runner manager status checks
          allow_next_instance_of(::Gitlab::Ci::RunnerUpgradeCheck) do |instance|
            allow(instance).to receive(:check_runner_upgrade_suggestion)
              .with(runner_manager1.version)
              .and_return([nil, manager1_version_status])
              .once
            allow(instance).to receive(:check_runner_upgrade_suggestion)
              .with(runner_manager2.version)
              .and_return([nil, manager2_version_status])
              .once
          end
        end

        shared_examples 'when runner managers have all possible statuses' do
          where(:manager1_version_status, :manager2_version_status,
            :expected_manager1_upgrade_status,
            :expected_manager2_upgrade_status, :expected_upgrade_status) do
            :error           | :error           | nil             | nil             | nil
            :invalid_version | :invalid_version | 'INVALID'       | 'INVALID'       | 'INVALID'
            :unavailable     | :unavailable     | 'NOT_AVAILABLE' | 'NOT_AVAILABLE' | 'NOT_AVAILABLE'
            :unavailable     | :available       | 'NOT_AVAILABLE' | 'AVAILABLE'     | 'AVAILABLE'
            :unavailable     | :recommended     | 'NOT_AVAILABLE' | 'RECOMMENDED'   | 'RECOMMENDED'
            :available       | :unavailable     | 'AVAILABLE'     | 'NOT_AVAILABLE' | 'AVAILABLE'
            :available       | :available       | 'AVAILABLE'     | 'AVAILABLE'     | 'AVAILABLE'
            :available       | :recommended     | 'AVAILABLE'     | 'RECOMMENDED'   | 'RECOMMENDED'
            :recommended     | :recommended     | 'RECOMMENDED'   | 'RECOMMENDED'   | 'RECOMMENDED'
          end

          with_them do
            it_behaves_like 'runner details fetch operation returning expected upgradeStatus'
          end
        end

        context 'requested by non-paid user' do
          let(:current_user) { admin }

          context 'with RunnerUpgradeCheck returning :available' do
            let(:manager1_version_status) { :available }
            let(:manager2_version_status) { :available }
            let(:expected_manager1_upgrade_status) { nil }
            let(:expected_manager2_upgrade_status) { nil }
            let(:expected_upgrade_status) { nil } # non-paying users always see nil

            it_behaves_like 'runner details fetch operation returning expected upgradeStatus'
          end
        end

        context 'requested on an instance with runner_upgrade_management' do
          let(:current_user) { admin }

          before do
            stub_licensed_features(runner_upgrade_management: true)
          end

          it_behaves_like 'when runner managers have all possible statuses'

          context 'with multiple runners' do
            let(:admin2) { create(:admin) }
            let(:query) do
              managers_path = query_graphql_path(%i[managers nodes], 'upgradeStatus')

              wrap_fields(query_graphql_path(%i[runners nodes], "id upgradeStatus #{managers_path}"))
            end

            it 'does not generate N+1 queries', :request_store, :use_sql_query_cache do
              # warm-up cache and so on:
              personal_access_token = create(:personal_access_token, user: admin)
              personal_access_token2 = create(:personal_access_token, user: admin)
              args = { current_user: admin, token: { personal_access_token: personal_access_token } }
              args2 = { current_user: admin2, token: { personal_access_token: personal_access_token2 } }

              control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
                post_graphql(query, **args)
              end

              create(:ci_runner)

              expect { post_graphql(query, **args2) }.not_to exceed_all_query_limit(control)
            end
          end
        end

        context 'requested by paid user' do
          let_it_be(:user) { create(:user, :admin, namespace: create(:user_namespace)) }
          let_it_be(:ultimate_group) do
            create(:group_with_plan, plan: :ultimate_plan, reporters: user)
          end

          let(:current_user) { user }

          it_behaves_like 'when runner managers have all possible statuses'
        end
      end

      context 'integration test with Gitlab::Ci::RunnerUpgradeCheck' do
        before do
          stub_licensed_features(runner_upgrade_management: true)
          stub_runner_releases(%w[14.0.0 14.1.0])
        end

        let(:current_user) { admin }

        let(:query) do
          managers_path = query_graphql_path(%i[managers nodes], 'id upgradeStatus')

          wrap_fields(query_graphql_path(query_path, "id upgradeStatus #{managers_path}"))
        end

        let(:query_path) do
          [
            [:runner, { id: runner.to_global_id.to_s }]
          ]
        end

        it 'retrieves expected fields' do
          post_graphql(query, current_user: current_user)

          runner_data = graphql_data_at(:runner)
          expect(graphql_dig_at(runner_data, :managers, :nodes)).to match [
            a_graphql_entity_for(runner_manager1, upgrade_status: 'NOT_AVAILABLE'),
            a_graphql_entity_for(runner_manager2, upgrade_status: 'AVAILABLE')
          ]
        end
      end
    end
  end

  describe 'jobsStatistics', :freeze_time do
    let_it_be(:maintainer) { create(:user) }
    let_it_be(:developer) { create(:user) }
    let_it_be(:group) { create(:group, maintainers: maintainer, developers: developer) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:project_runner1) { create(:ci_runner, :project, projects: [project]) }
    let_it_be(:project_runner2) { create(:ci_runner, :project, projects: [project]) }
    let_it_be(:pipeline1) { create(:ci_pipeline, project: project) }
    let_it_be(:pipeline2) { create(:ci_pipeline, project: project) }

    let(:runner_performance_insights) { true }
    let(:with_builds) { true }
    let(:query_path) { %i[runners jobs_statistics] }
    let(:query) do
      %(
        query {
          runners(type: PROJECT_TYPE) {
            jobsStatistics { #{all_graphql_fields_for('CiJobsStatistics')} }
          }
        }
      )
    end

    before do
      stub_licensed_features(runner_performance_insights: runner_performance_insights)

      if with_builds
        create(:ci_build, :running, runner: project_runner1, pipeline: pipeline1,
          queued_at: 5.minutes.ago, started_at: 1.minute.ago)
        create(:ci_build, :success, runner: project_runner2, pipeline: pipeline2,
          queued_at: 10.minutes.ago, started_at: 8.minutes.ago, finished_at: 7.minutes.ago)
      end
    end

    subject(:jobs_data) do
      post_graphql(query, current_user: current_user)

      graphql_data_at(*query_path)
    end

    context 'when requested by an administrator' do
      let(:current_user) { admin }

      it 'retrieves expected fields' do
        expect(jobs_data).not_to be_nil
        expect(jobs_data).to match a_hash_including(
          'queuedDuration' => {
            'mean' => nil, # Not yet handled
            'p50' => 180.0,
            'p75' => 210.0,
            'p90' => 228.0,
            'p95' => 234.0,
            'p99' => 238.8
          }
        )
      end

      context 'with no builds' do
        let(:with_builds) { false }

        it 'retrieves expected fields with nil values' do
          expect(jobs_data).not_to be_nil
          expect(jobs_data).to match a_hash_including(
            'queuedDuration' => {
              'mean' => nil, # Not yet handled
              'p50' => nil,
              'p75' => nil,
              'p90' => nil,
              'p95' => nil,
              'p99' => nil
            }
          )
        end
      end

      context 'when unlicensed' do
        let(:runner_performance_insights) { false }

        it { is_expected.to be_nil }
      end
    end

    context 'when requested by a regular user' do
      let_it_be(:current_user) { developer }

      it { is_expected.to be_nil }
    end

    describe 'Query.group.runners.jobsStatistics' do
      let(:query_path) { %i[group runners jobs_statistics] }
      let(:query) do
        %(
          query {
            group(fullPath: "#{group.full_path}") {
              runners(type: PROJECT_TYPE) {
                jobsStatistics { #{all_graphql_fields_for('CiJobsStatistics')} }
              }
            }
          }
        )
      end

      before do
        stub_licensed_features(runner_performance_insights_for_namespace: runner_performance_insights)
      end

      context 'when requested by a maintainer' do
        let(:current_user) { maintainer }

        it 'retrieves expected fields' do
          expect(jobs_data).not_to be_nil
          expect(jobs_data).to match a_hash_including(
            'queuedDuration' => {
              'mean' => nil, # Not yet handled
              'p50' => 180.0,
              'p75' => 210.0,
              'p90' => 228.0,
              'p95' => 234.0,
              'p99' => 238.8
            }
          )
        end

        context 'when unlicensed' do
          let(:runner_performance_insights) { false }

          it { is_expected.to be_nil }
        end
      end

      context 'when requested by a developer' do
        let_it_be(:current_user) { developer }

        it { is_expected.to be_nil }
      end
    end
  end

  describe 'ownerProject' do
    let_it_be(:project) { create(:project, :private) }
    let_it_be(:runner) { create(:ci_runner, :project, projects: [project]) }

    let(:query_path) do
      [
        [:runner, { id: runner.to_global_id.to_s }]
      ]
    end

    let(:query) do
      project_path = query_graphql_path([:ownerProject], '__typename')
      wrap_fields(query_graphql_path(query_path, project_path))
    end

    context 'when current user is an admin', :enable_admin_mode, feature_category: :permissions do
      let_it_be(:current_user) { admin }

      before do
        post_graphql(query, current_user: current_user)
      end

      it 'returns the project as ProjectType' do
        runner_data = graphql_data_at(:runner)
        expect(graphql_dig_at(runner_data, :ownerProject, :__typename)).to eq 'Project'
      end
    end

    context 'when current user is not an admin but has read_admin_cicd custom admin role',
      :enable_admin_mode, feature_category: :permissions do
      let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
      let_it_be(:current_user) { role.user }

      before do
        stub_licensed_features(custom_roles: true)

        post_graphql(query, current_user: current_user)
      end

      it 'returns the project as ProjectMinimalAccessType' do
        runner_data = graphql_data_at(:runner)
        expect(graphql_dig_at(runner_data, :ownerProject, :__typename)).to eq 'ProjectMinimalAccess'
      end
    end
  end

  describe 'groups' do
    let_it_be(:group) { create(:group, :private, :with_avatar) }
    let_it_be(:runner) { create(:ci_runner, :group, groups: [group]) }

    let(:query_path) do
      [
        [:runner, { id: runner.to_global_id.to_s }]
      ]
    end

    context 'when current user is not an admin but has read_admin_cicd custom admin role',
      :enable_admin_mode, feature_category: :permissions do
      let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
      let_it_be(:current_user) { role.user }

      let(:query) do
        group_path = query_graphql_path(%i[groups nodes], '__typename')

        wrap_fields(query_graphql_path(query_path, group_path))
      end

      before do
        stub_licensed_features(custom_roles: true)

        post_graphql(query, current_user: current_user)
      end

      it 'retrieves groups as GroupMinimalAccessType', :aggregate_failures do
        runner_data = graphql_data_at(:runner)
        expect(graphql_dig_at(runner_data, :groups, :nodes).flat_map(&:values)).to match %w[GroupMinimalAccess]
      end

      describe 'Query limits' do
        let_it_be(:args) do
          { current_user: current_user,
            token: { personal_access_token: create(:personal_access_token, user: current_user) } }
        end

        let(:one_group_runner_query) { group_runners_query(runner) }

        let(:runner_fragment) do
          <<~QUERY
            groups {
              nodes {
                name
              }
            }
          QUERY
        end

        it 'avoids N+1 queries', :use_sql_query_cache do
          control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
            post_graphql(one_group_runner_query, **args)
          end

          additional_runners = setup_additional_runners

          expect do
            post_graphql(group_runners_query(additional_runners), **args)

            raise StandardError, flattened_errors if graphql_errors # Ensure any error in query causes test to fail
          end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
        end

        def group_runners_query(runners)
          <<~QUERY
            {
              #{Array.wrap(runners).each_with_index.map { |r, i| runner_query(r, 1 + i) }.join("\n")}
            }
          QUERY
        end

        def runner_query(runner, runner_number)
          <<~QUERY
            runner#{runner_number}: runner(id: "#{runner.to_global_id}") {
              #{runner_fragment}
            }
          QUERY
        end

        def setup_additional_runners
          runner2 = create(:ci_runner, :group, groups: [create(:group)])
          runner3 = create(:ci_runner, :group, groups: [create(:group)])
          runner4 = create(:ci_runner, :group, groups: [create(:group)])

          [runner2, runner3, runner4]
        end
      end
    end
  end

  describe 'jobs' do
    let_it_be(:project) { create(:project, :private, public_builds: false) }
    let_it_be(:runner) { create(:ci_runner) }
    let_it_be(:build) do
      create(:ci_build, :failed, :trace_live, :erased, runner: runner, project: project, coverage: 1,
        scheduled_at: Time.now)
    end

    let(:query) do
      jobs_path = query_graphql_path(%i[jobs nodes], all_graphql_fields_for('CiJobInterface'))

      wrap_fields(query_graphql_path(query_path, jobs_path))
    end

    let(:query_path) do
      [
        [:runner, { id: runner.to_global_id.to_s }]
      ]
    end

    context 'when current user is an admin' do
      let_it_be(:current_user) { create(:admin) }
      let(:build) do
        create(:ci_build, :failed, :trace_live, :erased, runner: runner, project: project, coverage: 1,
          scheduled_at: Time.now)
      end

      before do
        stub_application_setting(ci_job_live_trace_enabled: true)
        build
        post_graphql(query, current_user: current_user)
      end

      it 'all fields have values' do
        exposed_field_values = graphql_data_at(:runner, :jobs, :nodes, 0).except('exitCode').values

        expect(exposed_field_values.any?(&:nil?)).to be false
      end
    end

    context 'when current user is not an admin but has read_admin_cicd custom admin role',
      :enable_admin_mode, feature_category: :permissions do
      let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
      let_it_be(:current_user) { role.user }

      let(:exposed_field_names) do
        ::Types::Ci::JobMinimalAccessType.own_fields.keys
      end

      let(:unexposed_field_names) do
        ::Types::Ci::JobInterface.fields.keys - exposed_field_names
      end

      before do
        stub_licensed_features(custom_roles: true)

        post_graphql(query, current_user: current_user)
      end

      it 'only exposed fields have values', :aggregate_failures do
        job_data = graphql_data_at(:runner, :jobs, :nodes, 0)

        exposed_field_values = job_data.slice(*exposed_field_names).values
        expect(exposed_field_values.any?(&:nil?)).to be false

        unexposed_field_values = job_data.slice(*unexposed_field_names).values
        expect(unexposed_field_values).to be_all(&:nil?)
      end
    end
  end
end
