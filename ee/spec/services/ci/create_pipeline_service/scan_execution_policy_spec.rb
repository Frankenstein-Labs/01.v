# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do # rubocop:disable RSpec/SpecFilePathFormat -- integration spec grouped by topic
  include RepoHelpers

  subject(:execute) { service.execute(source, **opts) }

  let(:source) { :push }
  let(:opts) { {} }
  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :repository, :auto_devops_disabled, group: group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be_with_reload(:project_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be_with_reload(:project_configuration) do
    create(:security_orchestration_policy_configuration,
      project: project, security_policy_management_project: project_policies_project)
  end

  let(:project_ci_yaml) do
    <<~YAML
      build:
        stage: build
        script:
          - echo 'build'
      rspec:
        stage: test
        script:
          - echo 'test'
    YAML
  end

  let(:service) { described_class.new(project, user, params) }
  let(:params) { { ref: 'master' } }

  before do
    stub_licensed_features(security_orchestration_policies: true, dependency_scanning: true, sast: true)
    # Ensure GITLAB_FEATURES CI variable includes dependency_scanning and sast features.
    # stub_licensed_features stubs License.feature_available? but does not populate
    # License.current.features which is used to build the GITLAB_FEATURES predefined variable.
    allow(License).to receive(:current).and_return(build(:license, plan: License::ULTIMATE_PLAN))
  end

  describe 'variables enforcement' do
    describe 'dependency scanning with DS_ENFORCE_NEW_ANALYZER' do
      let(:scan_execution_policy) do
        build(:scan_execution_policy,
          actions: [{ scan: 'dependency_scanning', template: 'latest' }],
          rules: [{ type: 'pipeline', branches: %w[master] }])
      end

      let(:project_policy_yaml) do
        build(:orchestration_policy_yaml, scan_execution_policy: [scan_execution_policy])
      end

      let(:project_files) do
        { '.gitlab-ci.yml' => project_ci_yaml, 'Gemfile.lock' => 'GEM REMOTE' }
      end

      around do |example|
        create_and_delete_files(project, project_files) do
          create_and_delete_files(
            project_policies_project,
            { '.gitlab/security-policies/policy.yml' => project_policy_yaml }
          ) do
            example.run
          end
        end
      end

      before do
        create(:security_policy, :scan_execution_policy, linked_projects: [project],
          content: scan_execution_policy.slice(:actions),
          security_orchestration_policy_configuration: project_configuration)
      end

      context 'when project sets DS_ENFORCE_NEW_ANALYZER to true as a CI variable' do
        before do
          create(:ci_variable, project: project, key: 'DS_ENFORCE_NEW_ANALYZER', value: 'true')
        end

        it 'creates the new unified dependency-scanning job instead of gemnasium jobs', :aggregate_failures do
          result = execute
          expect(result).to be_success

          all_jobs = result.payload.builds.map(&:name)

          expect(all_jobs).to include('dependency-scanning-0')
          expect(all_jobs).not_to include('gemnasium-dependency-scanning-0')
        end
      end

      context 'when policy action sets DS_ENFORCE_NEW_ANALYZER to true' do
        let(:scan_execution_policy) do
          build(:scan_execution_policy,
            actions: [{
              scan: 'dependency_scanning',
              template: 'latest',
              variables: { 'DS_ENFORCE_NEW_ANALYZER' => 'true' }
            }],
            rules: [{ type: 'pipeline', branches: %w[master] }])
        end

        it 'creates the new unified dependency-scanning job', :aggregate_failures do
          result = execute
          expect(result).to be_success

          all_jobs = result.payload.builds.map(&:name)

          expect(all_jobs).to include('dependency-scanning-0')
          expect(all_jobs).not_to include('gemnasium-dependency-scanning-0')
        end

        context 'when project tries to override DS_ENFORCE_NEW_ANALYZER to false' do
          before do
            create(:ci_variable, project: project, key: 'DS_ENFORCE_NEW_ANALYZER', value: 'false')
          end

          it 'enforces the policy variable and still uses the new unified job', :aggregate_failures do
            result = execute
            expect(result).to be_success

            all_jobs = result.payload.builds.map(&:name)

            expect(all_jobs).to include('dependency-scanning-0')
            expect(all_jobs).not_to include('gemnasium-dependency-scanning-0')
          end

          it 'does not allow the project variable to override the policy variable' do
            pipeline = execute.payload
            ds_job = pipeline.builds.find_by(name: 'dependency-scanning-0')

            expect(ds_job).to be_present
            expect(get_job_variable(ds_job, 'DS_ENFORCE_NEW_ANALYZER')).to eq('true')
          end
        end
      end
    end

    describe 'SAST with schedule and pipeline policies having different variables' do
      let(:scheduled_sast_policy) do
        build(:scan_execution_policy,
          name: 'Scheduled SEP',
          actions: [{
            scan: 'sast',
            variables: {
              'SECURE_ENABLE_LOCAL_CONFIGURATION' => 'false',
              'GITLAB_ADVANCED_SAST_ENABLED' => 'true'
            }
          }],
          rules: [{ type: 'schedule', cadence: '0 0 * * *', branch_type: 'all' }],
          skip_ci: { allowed: true })
      end

      let(:pipeline_sast_policy) do
        build(:scan_execution_policy,
          name: 'Pipeline SEP',
          actions: [{
            scan: 'sast',
            variables: {
              'SECURE_ENABLE_LOCAL_CONFIGURATION' => 'false',
              'GITLAB_ADVANCED_SAST_ENABLED' => 'false'
            }
          }],
          rules: [{ type: 'pipeline', branch_type: 'all' }],
          skip_ci: { allowed: true })
      end

      let(:project_policy_yaml) do
        build(:orchestration_policy_yaml,
          scan_execution_policy: [scheduled_sast_policy, pipeline_sast_policy])
      end

      around do |example|
        create_and_delete_files(project, { '.gitlab-ci.yml' => project_ci_yaml }) do
          create_and_delete_files(
            project_policies_project,
            { '.gitlab/security-policies/policy.yml' => project_policy_yaml }
          ) do
            example.run
          end
        end
      end

      before do
        create(:security_policy, :scan_execution_policy,
          name: 'Scheduled SEP',
          linked_projects: [project],
          policy_index: 0,
          content: scheduled_sast_policy.slice(:actions).merge(skip_ci: { allowed: true }),
          security_orchestration_policy_configuration: project_configuration)

        create(:security_policy, :scan_execution_policy,
          name: 'Pipeline SEP',
          linked_projects: [project],
          policy_index: 1,
          content: pipeline_sast_policy.slice(:actions).merge(skip_ci: { allowed: true }),
          security_orchestration_policy_configuration: project_configuration)
      end

      it 'only injects the pipeline policy jobs, not the scheduled policy jobs', :aggregate_failures do
        expect(execute).to be_success

        pipeline = execute.payload
        test_stage = pipeline.stages.find_by(name: 'test')
        job_names = test_stage.builds.map(&:name)

        expect(job_names).to include('semgrep-sast-0')
        expect(job_names).not_to include('gitlab-advanced-sast-0')
      end

      it 'uses the pipeline policy variables, not the scheduled policy variables', :aggregate_failures do
        pipeline = execute.payload
        test_stage = pipeline.stages.find_by(name: 'test')
        semgrep_job = test_stage.builds.find_by(name: 'semgrep-sast-0')

        expect(semgrep_job).to be_present
        expect(get_job_variable(semgrep_job, 'GITLAB_ADVANCED_SAST_ENABLED')).to eq('false')
        expect(get_job_variable(semgrep_job, 'SECURE_ENABLE_LOCAL_CONFIGURATION')).to eq('false')
      end
    end
  end

  describe 'scheduled scan execution policy job_options' do
    let(:source) { ::Security::SecurityOrchestrationPolicies::CreatePipelineService::PIPELINE_SOURCE }
    let(:policy_name) { 'Scheduled Security Scans' }
    let(:actions) { [{ scan: 'secret_detection' }, { scan: 'sast' }] }

    let(:ci_configs) do
      context = Gitlab::Ci::Config::External::Context.new(project: project, user: user)
      ::Security::SecurityOrchestrationPolicies::ScanPipelineService.new(
        context,
        branch: 'master',
        pipeline_source: source
      ).execute(actions)
    end

    let(:ci_config) { ci_configs[:pipeline_scan] }
    let(:scan_variables_map) { ci_configs[:variables] }

    let(:secret_detection_exceptions) { %w[SECRET_DETECTION_HISTORIC_SCAN SECRET_DETECTION_EXCLUDED_PATHS] }
    let(:sast_exceptions) do
      %w[DEFAULT_SAST_EXCLUDED_PATHS SAST_EXCLUDED_PATHS SAST_EXCLUDED_ANALYZERS ADVANCED_SAST_PARTIAL_SCAN]
    end

    let(:opts) do
      {
        content: ci_config.to_yaml,
        scan_execution_policy_context_block: ->(args) do
          args.merge(policy_name: policy_name, scan_variables_map: scan_variables_map)
        end,
        ignore_skip_ci: true
      }
    end

    it 'applies per-job variables_override exceptions', :aggregate_failures do
      result = execute
      expect(result).to be_success

      pipeline = result.payload
      secret_detection_build = pipeline.builds.find_by!(name: 'secret-detection-0')
      sast_build = pipeline.builds.find_by!(name: 'semgrep-sast-1')

      expect(secret_detection_build.options[:policy]).to include(
        name: policy_name,
        variables_override: { allowed: true, exceptions: secret_detection_exceptions }
      )

      expect(sast_build.options[:policy]).to include(
        name: policy_name,
        variables_override: { allowed: true, exceptions: sast_exceptions }
      )
    end

    context 'when there is no prior secret detection scan' do
      it 'runs a historic scan', :aggregate_failures do
        result = execute
        expect(result).to be_success

        pipeline = result.payload
        secret_detection_job = pipeline.builds.find_by!(name: 'secret-detection-0')

        expect(get_job_variable(secret_detection_job, 'SECRET_DETECTION_HISTORIC_SCAN')).to eq('true')
      end

      context 'when project sets SECRET_DETECTION_HISTORIC_SCAN to false as a CI variable' do
        before do
          create(:ci_variable, project: project, key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'false')
        end

        it 'does not allow the project variable to override the historic scan', :aggregate_failures do
          result = execute
          expect(result).to be_success

          pipeline = result.payload
          secret_detection_job = pipeline.builds.find_by!(name: 'secret-detection-0')

          expect(get_job_variable(secret_detection_job, 'SECRET_DETECTION_HISTORIC_SCAN')).to eq('true')
        end
      end
    end

    context 'when there is a prior secret detection scan' do
      let(:prior_pipeline) do
        create(:ci_pipeline, :success,
          source: :security_orchestration_policy,
          project: project,
          ref: 'master',
          sha: project.repository.commit('master').sha)
      end

      let(:prior_build) { create(:ci_build, :success, pipeline: prior_pipeline, project: project) }

      let!(:prior_scan) do
        create(:security_scan, :latest_successful,
          scan_type: :secret_detection,
          build: prior_build,
          pipeline: prior_pipeline,
          project: project)
      end

      it 'does not run a historic scan', :aggregate_failures do
        result = execute
        expect(result).to be_success

        pipeline = result.payload
        secret_detection_job = pipeline.builds.find_by!(name: 'secret-detection-0')

        expect(get_job_variable(secret_detection_job, 'SECRET_DETECTION_HISTORIC_SCAN')).to eq('false')
      end

      context 'when project sets SECRET_DETECTION_HISTORIC_SCAN to true as a CI variable' do
        before do
          create(:ci_variable, project: project, key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'true')
        end

        it 'does not allow the project variable to override the policy default', :aggregate_failures do
          result = execute
          expect(result).to be_success

          pipeline = result.payload
          secret_detection_job = pipeline.builds.find_by!(name: 'secret-detection-0')

          expect(get_job_variable(secret_detection_job, 'SECRET_DETECTION_HISTORIC_SCAN')).to eq('false')
        end
      end
    end
  end

  describe 'scheduled DAST scan execution policy job_options' do
    let(:source) { :ondemand_dast_scan }
    let(:policy_name) { 'Scheduled DAST Policy' }
    let(:dast_action) { { scan: 'dast', site_profile: dast_site_profile.name } }
    let(:dast_action_with_variables) do
      { scan: 'dast', site_profile: dast_site_profile.name, variables: { DAST_SPIDER_MINS: '5' } }
    end

    let_it_be(:dast_site_profile) { create(:dast_site_profile, project: project) }

    let(:actions) { [dast_action] }

    let(:ci_configs) do
      context = Gitlab::Ci::Config::External::Context.new(project: project, user: user)
      ::Security::SecurityOrchestrationPolicies::ScanPipelineService.new(
        context,
        branch: 'master',
        pipeline_source: ::Security::SecurityOrchestrationPolicies::CreatePipelineService::PIPELINE_SOURCE
      ).execute(actions)
    end

    let(:ci_config) do
      on_demand = ci_configs[:on_demand]
      on_demand[:stages] = [
        *Gitlab::Ci::Config::Entry::Stages.default,
        AppSec::Dast::ScanConfigs::BuildService::STAGE_NAME
      ]
      on_demand
    end

    let(:scan_variables_map) { ci_configs[:variables] }

    let(:opts) do
      {
        content: ci_config.to_yaml,
        scan_execution_policy_context_block: ->(args) do
          args.merge(policy_name: policy_name, scan_variables_map: scan_variables_map)
        end
      }
    end

    before do
      stub_licensed_features(security_orchestration_policies: true, security_on_demand_scans: true)
    end

    it 'applies variables_override to DAST builds', :aggregate_failures do
      result = execute
      expect(result).to be_success

      pipeline = result.payload
      dast_build = pipeline.builds.find_by!(name: 'dast-on-demand-0')

      expect(dast_build.options[:policy]).to include(
        name: policy_name,
        variables_override: { allowed: true }
      )
    end

    context 'when the DAST action has custom variables' do
      let(:actions) { [dast_action_with_variables] }

      it 'includes the custom variables as exceptions in variables_override', :aggregate_failures do
        result = execute
        expect(result).to be_success

        pipeline = result.payload
        dast_build = pipeline.builds.find_by!(name: 'dast-on-demand-0')

        expect(dast_build.options[:policy]).to include(
          name: policy_name,
          variables_override: { allowed: true, exceptions: %w[DAST_SPIDER_MINS] }
        )
      end

      context 'when project sets a DAST variable as a CI variable' do
        before do
          create(:ci_variable, project: project, key: 'DAST_SPIDER_MINS', value: '99')
        end

        it 'does not allow the project variable to override the policy variable', :aggregate_failures do
          result = execute
          expect(result).to be_success

          pipeline = result.payload
          dast_build = pipeline.builds.find_by!(name: 'dast-on-demand-0')

          expect(get_job_variable(dast_build, 'DAST_SPIDER_MINS')).to eq('5')
        end
      end
    end
  end

  private

  def get_job_variable(job, key)
    job.scoped_variables.to_hash[key]
  end
end
