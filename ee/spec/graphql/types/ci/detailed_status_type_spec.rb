# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::DetailedStatusType, feature_category: :continuous_integration do
  include GraphqlHelpers

  describe 'deployment_details_path field' do
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:environment) { create(:environment, project: project) }
    let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
    let_it_be(:stage) { create(:ci_stage, pipeline: pipeline, project: project) }

    context 'when the job has no deployment' do
      it 'returns nil' do
        build = create(:ci_build, :success, pipeline: pipeline, ci_stage: stage)
        status = build.detailed_status(build.user)

        expect(resolve_field('deployment_details_path', status, arg_style: :internal)).to be_nil
      end
    end

    context 'when the job has a deployment' do
      let(:build) { create(:ci_build, :manual, pipeline: pipeline, ci_stage: stage, environment: environment.name) }
      let(:deployment) { create(:deployment, :blocked, project: project, environment: environment, deployable: build) }

      before do
        create(:job_environment, environment: environment, job: build, deployment: deployment, project: project,
          pipeline: pipeline)
        stub_licensed_features(protected_environments: true)
      end

      context 'when the build is not waiting for approval' do
        it 'returns nil' do
          status = build.detailed_status(build.user)
          deployment_path = resolve_field('deployment_details_path', status, arg_style: :internal)

          expect(deployment_path).to be_nil
        end
      end
    end

    context 'when a bridge is waiting for approval' do
      let_it_be(:downstream_project) { create(:project, :repository) }
      let(:bridge) do
        create(:ci_bridge, :manual, pipeline: pipeline, ci_stage: stage, downstream: downstream_project,
          environment: environment.name)
      end

      let(:bridge_deployment) do
        create(:deployment, :blocked, project: project, environment: environment, deployable: bridge)
      end

      before do
        create(:job_environment, environment: environment, job: bridge, deployment: bridge_deployment,
          project: project, pipeline: pipeline)
        stub_licensed_features(protected_environments: true)
      end

      it 'returns the deployment details path' do
        bridge.reload

        core_status = Gitlab::Ci::Status::Core.new(bridge, bridge.user)
        status = Gitlab::Ci::Status::Bridge::WaitingForApproval.new(core_status)

        expect(bridge.deployment).to eq(bridge_deployment)

        deployment_path = resolve_field('deployment_details_path', status, arg_style: :internal)

        expect(deployment_path).to eq(
          Gitlab::Routing.url_helpers.project_environment_deployment_path(
            project, environment, bridge_deployment
          )
        )
      end
    end

    context 'when querying multiple jobs with deployments', :request_store do
      include GraphqlHelpers

      let_it_be(:user) { create(:user) }
      let(:query) do
        %(
          query {
            project(fullPath: "#{project.full_path}") {
              pipeline(iid: "#{pipeline.iid}") {
                stages {
                  nodes {
                    groups {
                      nodes {
                        jobs {
                          nodes {
                            detailedStatus {
                              id
                              deploymentDetailsPath
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        )
      end

      before_all do
        project.add_maintainer(user)
      end

      before do
        stub_licensed_features(protected_environments: true)
      end

      it 'avoids N+1 queries when accessing deployment_details_path', :use_sql_query_cache do
        downstream_project = create(:project, :repository)

        # Create initial set with both builds and bridges
        builds = create_list(:ci_build, 2, :manual, pipeline: pipeline, ci_stage: stage, environment: environment.name)
        builds.each do |build|
          deployment = create(:deployment, :blocked, project: project, environment: environment, deployable: build)
          create(:job_environment, environment: environment, job: build, deployment: deployment, project: project,
            pipeline: pipeline)
        end

        bridge = create(:ci_bridge, :manual, pipeline: pipeline, ci_stage: stage, downstream: downstream_project,
          environment: environment.name)
        bridge_deployment = create(:deployment, :blocked, project: project, environment: environment,
          deployable: bridge)
        create(:job_environment, environment: environment, job: bridge, deployment: bridge_deployment,
          project: project, pipeline: pipeline)

        run_with_clean_state(query, context: { current_user: user })

        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          run_with_clean_state(query, context: { current_user: user })
        end

        # Add more builds and bridges
        new_builds = create_list(:ci_build, 2, :manual, pipeline: pipeline, ci_stage: stage,
          environment: environment.name)
        new_builds.each do |build|
          deployment = create(:deployment, :blocked, project: project, environment: environment, deployable: build)
          create(:job_environment, environment: environment, job: build, deployment: deployment, project: project,
            pipeline: pipeline)
        end

        new_bridge = create(:ci_bridge, :manual, pipeline: pipeline, ci_stage: stage, downstream: downstream_project,
          environment: environment.name)
        new_bridge_deployment = create(:deployment, :blocked, project: project, environment: environment,
          deployable: new_bridge)
        create(:job_environment, environment: environment, job: new_bridge, deployment: new_bridge_deployment,
          project: project, pipeline: pipeline)

        expect do
          run_with_clean_state(query, context: { current_user: user })
        end.to issue_same_number_of_queries_as(control)
      end
    end
  end
end
