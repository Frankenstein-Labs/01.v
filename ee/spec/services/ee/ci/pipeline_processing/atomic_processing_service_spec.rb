# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::PipelineProcessing::AtomicProcessingService, feature_category: :continuous_integration do
  include RepoHelpers

  describe 'Pipeline Processing Service' do
    let_it_be(:project) { create(:project, :repository) }
    let(:pipeline) do
      create(:ci_empty_pipeline, ref: 'master', project: project)
    end

    let_it_be(:user) { create(:user) }

    before_all do
      project.add_owner(user)
    end

    subject(:process_pipeline) { described_class.new(pipeline).execute }

    context 'when protected environments are defined', :sidekiq_inline do
      let(:staging_job) { create_build('staging:deploy', environment: 'staging', user: user) }
      let(:production_job) { create_build('production:deploy', environment: 'production', user: user) }
      let(:approval_rules) do
        [
          build(
            :protected_environment_approval_rule,
            :maintainer_access,
            required_approvals: 2
          )
        ]
      end

      before do
        stub_licensed_features(protected_environments: true)

        # Protection for the staging environment
        staging = create(:environment, name: 'staging', project: project)
        create(:protected_environment, name: 'staging', project: project, authorize_user_to_deploy: user)
        create(:deployment, environment: staging, deployable: staging_job, project: project)

        # Protection for the production environment (with Deployment Approvals)
        production = create(:environment, name: 'production', project: project)

        create(
          :protected_environment,
          :maintainers_can_deploy,
          name: 'production',
          authorize_user_to_deploy: user,
          project: project,
          approval_rules: approval_rules
        )

        create(:deployment, environment: production, deployable: production_job, project: project)
      end

      it 'blocks pipeline on stage with first manual action' do
        process_pipeline

        expect(builds_names).to match_array %w[staging:deploy production:deploy]
        expect(staging_job.reload).to be_pending
        expect(staging_job.deployment).to be_created
        expect(production_job.reload).to be_manual
        expect(production_job.deployment).to be_blocked
        expect(pipeline.reload).to be_running
      end
    end

    context 'when there are jobs where needs is empty array' do
      before do
        stub_ci_pipeline_yaml_file(config)
      end

      let(:config) do
        <<~YAML
          regular_job:
            stage: build
            script: echo 'hello'
          bridge_dag_job:
            stage: test
            needs: []
            trigger: 'some/project'
        YAML
      end

      let(:pipeline) { create_pipeline }

      it 'creates a pipeline with regular_job and dag_job pending' do
        process_pipeline

        expect(pipeline).to be_persisted
        expect(find_job('regular_job').status).to eq('pending')
        expect(find_job('bridge_dag_job').status).to eq('pending')
      end
    end

    context 'with pipeline execution policy' do
      let(:config) do
        <<~YAML
          regular_job:
            stage: build
            script: echo 'hello'
          bridge_dag_job:
            stage: test
            needs: []
            trigger: 'some/project'
        YAML
      end

      let(:pipeline) { create_pipeline }
      let_it_be(:policies_project) { create(:project, :repository, :public) }
      let!(:project_configuration) do
        create(:security_orchestration_policy_configuration,
          project: project, security_policy_management_project: policies_project)
      end

      let(:project_policy_file) { 'project-policy.yml' }
      let(:project_policy) do
        build(:pipeline_execution_policy,
          content: { include: [{
            project: policies_project.full_path,
            file: project_policy_file,
            ref: policies_project.default_branch_or_main
          }] })
      end

      let(:policy_ci_yaml) do
        <<~YAML
          policy_job:
            stage: .pipeline-policy-pre
            script:
              -echo 'test'
        YAML
      end

      let(:project_policy_yaml) do
        build(:orchestration_policy_yaml, pipeline_execution_policy: [project_policy])
      end

      before do
        stub_licensed_features(security_orchestration_policies: true)
        stub_ci_pipeline_yaml_file(config)
      end

      around do |example|
        create_and_delete_files(
          policies_project, {
            '.gitlab/security-policies/policy.yml' => project_policy_yaml,
            project_policy_file => policy_ci_yaml
          }) do
          example.run
        end
      end

      it 'creates a pipeline with regular_job and bridge_dag_job created' do
        process_pipeline

        expect(pipeline).to be_persisted
        expect(find_job('policy_job').status).to eq('pending')
        expect(find_job('regular_job').status).to eq('created')
        expect(find_job('bridge_dag_job').status).to eq('created')
      end

      it 'starts the regular_job after .pipeline-policy-pre stage is done' do
        process_pipeline

        regular_job = find_job('regular_job')

        expect(regular_job.status).to eq('created')

        find_job('policy_job').success!
        Ci::ProcessPipelineService.new(pipeline).execute

        expect(regular_job.reload.status).to eq('pending')
      end

      shared_examples_for 'does not start processing of other jobs' do
        %w[drop! cancel!].each do |event|
          context "when policy job status transitions via #{event}" do
            it 'skips execution of other jobs' do
              process_pipeline

              regular_job = find_job('regular_job')
              bridge_dag_job = find_job('bridge_dag_job')

              expect(regular_job.status).to eq('created')
              expect(bridge_dag_job.status).to eq('created')

              find_job('policy_job').public_send(event)
              Ci::ProcessPipelineService.new(pipeline).execute

              expect(regular_job.reload.status).to eq('skipped')
              expect(bridge_dag_job.reload.status).to eq('skipped')
            end
          end
        end
      end

      it_behaves_like 'does not start processing of other jobs'

      context 'when there is a job with `when: always`' do
        let(:config) do
          <<~YAML
          regular_job:
            stage: build
            script: echo 'hello'
          bridge_dag_job:
            stage: test
            needs: []
            when: 'always'
            trigger: 'some/project'
          YAML
        end

        it_behaves_like 'does not start processing of other jobs'
      end

      context 'when there is a job with `when: always` but without empty needs' do
        let(:config) do
          <<~YAML
          regular_job:
            stage: build
            script: echo 'hello'
          bridge_dag_job:
            stage: test
            when: 'always'
            trigger: 'some/project'
          YAML
        end

        it_behaves_like 'does not start processing of other jobs'
      end

      context 'when .pipeline-policy-pre stage is allowed to fail' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_job:
              stage: .pipeline-policy-pre
              allow_failure: true
              script:
                -echo 'test'
          YAML
        end

        it 'starts jobs in other stages' do
          process_pipeline

          find_job('policy_job').drop!
          Ci::ProcessPipelineService.new(pipeline).execute
          expect(find_job('policy_job').status).to eq('failed')
          expect(find_job('regular_job').status).to eq('pending')
          expect(find_job('bridge_dag_job').status).to eq('pending')
        end
      end

      context 'when .pipeline-policy-pre stage contains jobs with empty needs' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_job:
              stage: .pipeline-policy-pre
              script:
                -echo 'test'
            policy_job_with_needs:
              stage: .pipeline-policy-pre
              needs: []
              script:
                -echo 'test'
          YAML
        end

        it 'starts both jobs in .pipeline-policy-pre stage and blocks jobs in other stages' do
          process_pipeline

          expect(pipeline).to be_persisted
          expect(find_job('policy_job').status).to eq('pending')
          expect(find_job('policy_job_with_needs').status).to eq('pending')
          expect(find_job('regular_job').status).to eq('created')
          expect(find_job('bridge_dag_job').status).to eq('created')
        end
      end

      context 'when .pipeline-policy-pre stage contains skipped jobs' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_job:
              stage: .pipeline-policy-pre
              when: on_failure
              script:
                -echo 'test'
          YAML
        end

        it 'skips all jobs in later stages' do
          process_pipeline

          expect(pipeline).to be_persisted
          expect(find_job('policy_job').status).to eq('skipped')
          expect(find_job('regular_job').status).to eq('skipped')
          expect(find_job('bridge_dag_job').status).to eq('skipped')
        end
      end

      context 'when .pipeline-policy-pre stage contains manual jobs' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_job:
              stage: .pipeline-policy-pre
              when: manual
              script:
                -echo 'test'
          YAML
        end

        it 'skips all later jobs' do
          process_pipeline

          expect(pipeline).to be_persisted
          expect(find_job('policy_job').status).to eq('manual')
          expect(find_job('regular_job').status).to eq('skipped')
          expect(find_job('bridge_dag_job').status).to eq('skipped')
        end
      end

      context 'when .pipeline-policy-pre stage contains a blocker manual job' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_job:
              stage: .pipeline-policy-pre
              when: manual
              allow_failure: false
              script:
                -echo 'test'
          YAML
        end

        it 'blocks the pipeline and does not start processing of other jobs' do
          process_pipeline

          expect(pipeline).to be_persisted
          expect(find_job('policy_job').status).to eq('manual')
          expect(find_job('regular_job').status).to eq('created')
          expect(find_job('bridge_dag_job').status).to eq('created')
        end
      end

      context 'with other policy jobs not on pre stage and empty needs' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_job:
              stage: .pipeline-policy-pre
              script:
                -echo 'test'
            policy_post_dag_job:
              stage: .pipeline-policy-post
              needs: []
              script:
                -echo 'test'
          YAML
        end

        it 'does not start the policy job on post stage' do
          process_pipeline

          expect(pipeline).to be_persisted
          expect(find_job('policy_job').status).to eq('pending')
          expect(find_job('policy_post_dag_job').status).to eq('created')
        end
      end

      context 'with other policy depending on each other' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_job:
              stage: .pipeline-policy-pre
              script:
                -echo 'test'
            policy_job_2:
              stage: .pipeline-policy-pre
              script:
                -echo 'test'
            policy_post_job:
              stage: .pipeline-policy-post
              needs: []
              script:
                -echo 'test'
          YAML
        end

        it 'does not start the policy job on post stage until the whole stage is complete' do
          process_pipeline

          expect(pipeline).to be_persisted
          expect(find_job('policy_job').status).to eq('pending')
          expect(find_job('policy_post_job').status).to eq('created')

          find_job('policy_job').success!
          Ci::ProcessPipelineService.new(pipeline).execute

          expect(find_job('policy_post_job').status).to eq('created')

          find_job('policy_job_2').success!
          Ci::ProcessPipelineService.new(pipeline).execute

          expect(find_job('policy_post_job').status).to eq('pending')
        end
      end

      context 'with inherited policy jobs' do
        let(:policy_ci_yaml) do
          <<~YAML
            policy_1_pre_job:
              stage: .pipeline-policy-pre
              script:
                - echo 'test'
            policy_1_post_job:
              stage: .pipeline-policy-post
              needs: []
              script:
                - echo 'test'
          YAML
        end

        let(:inherited_policy_ci_yaml) do
          <<~YAML
            policy_2_pre_job:
              stage: .pipeline-policy-pre
              script:
                - echo 'test'
            policy_2_post_job:
              stage: .pipeline-policy-post
              needs: []
              script:
                - echo 'test'
          YAML
        end

        let_it_be(:group) { create(:group) }
        let_it_be(:project) { create(:project, :repository, group: group) }
        let_it_be(:group_policies_project) { create(:project, :repository, :public) }
        let_it_be(:group_configuration) do
          create(:security_orchestration_policy_configuration, :namespace,
            namespace_id: group.id, security_policy_management_project: group_policies_project)
        end

        let(:group_policy) do
          build(:pipeline_execution_policy,
            content: { include: [{
              project: group_policies_project.full_path,
              file: project_policy_file,
              ref: group_policies_project.default_branch_or_main
            }] })
        end

        let(:group_policy_yaml) do
          build(:orchestration_policy_yaml, pipeline_execution_policy: [group_policy])
        end

        before_all do
          group.add_owner(user)
          project.add_owner(user)
        end

        around do |example|
          create_and_delete_files(
            group_policies_project, {
              '.gitlab/security-policies/policy.yml' => group_policy_yaml,
              project_policy_file => inherited_policy_ci_yaml
            }) do
            example.run
          end
        end

        it 'only starts processing jobs on post stage when all pre jobs are complete' do
          process_pipeline

          expect(pipeline).to be_persisted
          expect(find_job('policy_1_pre_job').status).to eq('pending')
          expect(find_job('policy_2_pre_job').status).to eq('pending')
          expect(find_job('policy_1_post_job').status).to eq('created')
          expect(find_job('policy_2_post_job').status).to eq('created')

          find_job('policy_1_pre_job').success!
          Ci::ProcessPipelineService.new(pipeline).execute

          expect(find_job('policy_1_post_job').status).to eq('created')
          expect(find_job('policy_2_post_job').status).to eq('created')

          find_job('policy_2_pre_job').success!
          Ci::ProcessPipelineService.new(pipeline).execute

          expect(find_job('policy_1_post_job').status).to eq('pending')
          expect(find_job('policy_2_post_job').status).to eq('pending')
        end

        context 'when policy jobs depend on each other' do
          let(:policy_ci_yaml) do
            <<~YAML
              policy_1_pre_job:
                stage: .pipeline-policy-pre
                script:
                  - echo 'test'
              policy_1_post_job:
                stage: .pipeline-policy-post
                needs: []
                script:
                  - echo 'test'
            YAML
          end

          let(:inherited_policy_ci_yaml) do
            <<~YAML
              policy_2_pre_job:
                stage: .pipeline-policy-pre
                script:
                  - echo 'test'
              policy_2_post_job:
                stage: .pipeline-policy-post
                needs:
                  - policy_2_pre_job
                script:
                  - echo 'test'
            YAML
          end

          it 'has to wait for all jobs in the pre stage to complete' do
            process_pipeline

            expect(pipeline).to be_persisted
            expect(find_job('policy_1_pre_job').status).to eq('pending')
            expect(find_job('policy_2_pre_job').status).to eq('pending')
            expect(find_job('policy_1_post_job').status).to eq('created')
            expect(find_job('policy_2_post_job').status).to eq('created')

            find_job('policy_1_pre_job').success!
            Ci::ProcessPipelineService.new(pipeline).execute

            expect(find_job('policy_2_post_job').status).to eq('created')

            find_job('policy_2_pre_job').success!
            Ci::ProcessPipelineService.new(pipeline).execute

            expect(find_job('policy_2_post_job').status).to eq('pending')
          end
        end
      end
    end

    private

    def all_builds
      pipeline.processables.order(:stage_idx, :id)
    end

    def builds
      all_builds.where.not(status: [:created, :skipped])
    end

    def builds_names
      builds.pluck(:name)
    end

    def create_build(name, **opts)
      create(:ci_build, :created, pipeline: pipeline, name: name, **opts)
    end

    def create_pipeline
      Ci::CreatePipelineService.new(project, user, { ref: 'refs/heads/master' }).execute(:push).payload
    end

    def find_job(name)
      pipeline.reload.processables.find { |processable| processable.name == name }
    end
  end
end
