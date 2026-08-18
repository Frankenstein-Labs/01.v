# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.jobs', feature_category: :continuous_integration do
  include GraphqlHelpers

  let(:query_jobs_args) { graphql_args }

  let(:query_path) do
    [
      [:jobs, query_jobs_args],
      [:nodes]
    ]
  end

  let(:query) do
    wrap_fields(query_graphql_path(query_path, 'id'))
  end

  let(:jobs_graphql_data) { graphql_data_at(:jobs, :nodes) }

  subject(:request) { post_graphql(query, current_user: current_user) }

  context 'when current user is an admin' do
    let_it_be(:current_user) { create(:admin) }
    let_it_be(:instance_runner) { create(:ci_runner, :instance) }

    let_it_be(:successful_job) { create(:ci_build, :success, name: 'successful_job') }
    let_it_be(:failed_job) { create(:ci_build, :failed, name: 'failed_job') }
    let_it_be(:pending_job) { create(:ci_build, :pending, name: 'pending_job') }
    let_it_be(:system_failure_job) do
      create(:ci_build, :failed, failure_reason: :runner_system_failure, runner: instance_runner,
        name: 'system_failure_job')
    end

    context "with argument `failure_reason`", feature_category: :fleet_visibility do
      let(:query_jobs_args) do
        graphql_args(failure_reason: failure_reason)
      end

      let_it_be(:_system_failure_on_project_runner) do
        project_runner = create(:ci_runner, :project, projects: [create(:project)])

        create(:ci_build, :failed, failure_reason: :runner_system_failure, runner: project_runner,
          name: 'system_failure_job2')
      end

      before do
        stub_licensed_features(runner_performance_insights: true)

        Ci::Build.all.find_each { |build| ::Ci::InstanceRunnerFailedJobs.track(build) }
      end

      context 'as RUNNER_SYSTEM_FAILURE' do
        let(:failure_reason) { :RUNNER_SYSTEM_FAILURE }

        it 'generates an error' do
          request

          expect_graphql_errors_to_include 'failure_reason can only be used together with runner_type: instance_type'
        end

        context 'with argument `runnerTypes`' do
          let(:query_jobs_args) do
            graphql_args(runner_types: runner_types, failure_reason: failure_reason)
          end

          context 'as INSTANCE_TYPE' do
            let(:runner_types) { [:INSTANCE_TYPE] }

            it_behaves_like 'a working graphql query that returns data' do
              before do
                request
              end

              it { expect(jobs_graphql_data).to contain_exactly(a_graphql_entity_for(system_failure_job)) }
            end
          end
        end
      end

      context 'as RUNNER_UNSUPPORTED' do
        let(:failure_reason) { :RUNNER_UNSUPPORTED }

        context 'with argument `runnerTypes`' do
          let(:query_jobs_args) do
            graphql_args(runner_types: runner_types, failure_reason: failure_reason)
          end

          context 'as INSTANCE_TYPE' do
            let(:runner_types) { [:INSTANCE_TYPE] }

            it 'generates an error' do
              request

              expect_graphql_errors_to_include 'failure_reason only supports runner_system_failure'
            end
          end
        end
      end
    end
  end

  describe 'fields', :enable_admin_mode, feature_category: :permissions do
    let_it_be(:runner) { create(:ci_runner) }
    let_it_be(:job) do
      create(:ci_build, :failed, :trace_live, :erased, runner: runner, coverage: 1, scheduled_at: Time.now)
    end

    let(:query) do
      wrap_fields(query_graphql_path(query_path, all_graphql_fields_for('CiJobInterface')))
    end

    context 'when current user is an admin' do
      let_it_be(:current_user) { create(:admin) }
      let(:job) do
        create(:ci_build, :failed, :trace_live, :erased, runner: runner, coverage: 1, scheduled_at: Time.now)
      end

      before do
        stub_application_setting(ci_job_live_trace_enabled: true)
        job
        post_graphql(query, current_user: current_user)
      end

      it 'all fields have values' do
        exposed_field_values = graphql_data_at(:jobs, :nodes, 0).except('exitCode').values

        expect(exposed_field_values.any?(&:nil?)).to be false
      end
    end

    context 'when current user is not an admin but has read_admin_cicd custom admin role' do
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
        job_data = graphql_data_at(:jobs, :nodes, 0)

        exposed_field_values = job_data.slice(*exposed_field_names).values
        expect(exposed_field_values.any?(&:nil?)).to be false

        unexposed_field_values = job_data.slice(*unexposed_field_names).values
        expect(unexposed_field_values).to be_all(&:nil?)
      end
    end
  end

  describe 'Query limits' do
    let_it_be(:current_user) { create(:admin) }
    let_it_be(:args) { { current_user: current_user } }

    let(:query) do
      wrap_fields(query_graphql_path(query_path, 'id'))
    end

    it 'avoids N+1 queries', :request_store, :use_sql_query_cache do
      control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
        post_graphql(query, **args)
      end

      create_list(:ci_build, 2)

      expect do
        post_graphql(query, **args)

        raise StandardError, flattened_errors if graphql_errors # Ensure any error in query causes test to fail
      end.not_to exceed_query_limit(control).allow_skip_cache_inconsistency
    end
  end

  describe 'Query.jobs.pipeline', :enable_admin_mode, feature_category: :permissions do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project, user: create(:user)) }
    let_it_be(:job) { create(:ci_build, pipeline: pipeline) }

    let(:query) do
      pipeline_path = query_graphql_path([:pipeline], all_graphql_fields_for('PipelineInterface'))

      wrap_fields(query_graphql_path(query_path, pipeline_path))
    end

    context 'when current user is an admin' do
      let_it_be(:current_user) { create(:admin) }

      before do
        post_graphql(query, current_user: current_user)
      end

      it 'all fields have values' do
        exposed_field_values = graphql_data_at(:jobs, :nodes, :pipeline)[0].values

        expect(exposed_field_values).to be_all(&:present?)
      end
    end

    context 'when current user is not an admin but has read_admin_cicd custom admin role' do
      let_it_be(:role) { create(:admin_member_role, :read_admin_cicd) }
      let_it_be(:current_user) { role.user }

      let(:exposed_field_names) do
        ::Types::Ci::PipelineMinimalAccessType.own_fields.keys
      end

      let(:unexposed_field_names) do
        ::Types::Ci::PipelineInterface.fields.keys - exposed_field_names
      end

      before do
        stub_licensed_features(custom_roles: true)

        post_graphql(query, current_user: current_user)
      end

      it 'only exposed fields have values', :aggregate_failures do
        pipeline_data = graphql_data_at(:jobs, :nodes, :pipeline, 0)

        exposed_field_values = pipeline_data.slice(*exposed_field_names).values
        expect(exposed_field_values).to be_all(&:present?)

        unexposed_field_values = pipeline_data.slice(*unexposed_field_names).values
        expect(unexposed_field_values).to be_all(&:blank?)
      end
    end
  end
end
