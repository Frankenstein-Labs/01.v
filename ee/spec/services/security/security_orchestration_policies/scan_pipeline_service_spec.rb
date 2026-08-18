# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::ScanPipelineService,
  :yaml_processor_feature_flag_corectness,
  feature_category: :security_policy_management do
  describe '#execute' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :small_repo, group: group) }
    let_it_be(:user) { create(:user) }

    let(:pipeline_scan_config) { subject[:pipeline_scan] }
    let(:on_demand_config) { subject[:on_demand] }
    let(:variables_config) { subject[:variables] }
    let(:service) { described_class.new(context, branch: branch, pipeline_source: pipeline_source) }
    let(:context) { Gitlab::Ci::Config::External::Context.new(project: project, user: user) }
    let(:pipeline) { nil }
    let(:branch) { project.default_branch_or_main }
    let(:pipeline_source) { nil }

    subject(:execute) { service.execute(actions) }

    shared_examples 'creates scan jobs' do |on_demand_jobs: [], pipeline_scan_job_templates: [], variables: {}|
      it 'calls the services' do
        expect(::Security::SecurityOrchestrationPolicies::CiConfigurationService).to receive(:new)
          .exactly(pipeline_scan_job_templates.size)
          .times
          .and_call_original
        expect(::Security::SecurityOrchestrationPolicies::OnDemandScanPipelineConfigurationService).to receive(:new)
          .exactly(on_demand_jobs.count)
          .times
          .and_call_original

        execute
      end

      if pipeline_scan_job_templates.any?
        it 'returns created pipeline scan jobs' do
          expected_pipeline_scan_jobs = []

          pipeline_scan_job_templates.each_with_index do |job_template, index|
            template = ::TemplateFinder.build(:gitlab_ci_ymls, nil, name: job_template).execute
            jobs = Gitlab::Ci::Config.new(template.content).jobs.keys
            jobs.each do |job|
              expected_pipeline_scan_jobs.append(:"#{job.to_s.tr('_', '-')}-#{index}")
            end
          end

          expect(pipeline_scan_config.keys).to eq(expected_pipeline_scan_jobs + %i[variables])
        end
      else
        it 'does not return pipeline scan jobs' do
          expect(pipeline_scan_config.keys).to be_empty
        end
      end

      if on_demand_jobs.any?
        it 'returns created on demand jobs' do
          expect(on_demand_config.keys).to eq(on_demand_jobs + %i[variables])
        end
      else
        it 'does not return on demand jobs' do
          expect(on_demand_config.keys).to be_empty
        end
      end

      it 'returns variables' do
        expect(variables_config).to match a_hash_including(variables)
      end
    end

    shared_examples 'does not create scan jobs' do
      it 'does not create scan job' do
        expect(::Security::SecurityOrchestrationPolicies::CiConfigurationService).not_to receive(:new)
        expect(::Security::SecurityOrchestrationPolicies::OnDemandScanPipelineConfigurationService).not_to receive(:new)

        [pipeline_scan_config, on_demand_config].each do |config|
          expect(config.keys).to eq([])
        end
      end
    end

    shared_examples 'returns empty result' do
      it 'returns empty result' do
        expect(subject.values_at(:pipeline_scan, :on_demand, :variables)).to all(be_empty)
      end
    end

    context 'when a job_name_suffix is given' do
      let(:actions) { [{ scan: 'secret_detection' }, { scan: 'sast' }] }
      let(:service) { described_class.new(context, job_name_suffix: 'profile') }

      it 'suffixes every generated job name', :aggregate_failures do
        expect(pipeline_scan_config.keys).to include(:'secret-detection-profile-0', :'sast-profile-1')
      end
    end

    context 'when there is an invalid action' do
      let(:actions) { [{ scan: 'invalid' }] }

      include_examples 'does not create scan jobs'
      include_examples 'returns empty result'
    end

    context 'when there are no actions' do
      let(:actions) { [] }

      include_examples 'does not create scan jobs'
      include_examples 'returns empty result'

      it 'does not observe histogram' do
        expect(::Security::SecurityOrchestrationPolicies::ObserveHistogramsService).not_to receive(:measure)

        subject
      end
    end

    context 'when there is only one action' do
      let(:actions) { [{ scan: 'secret_detection' }] }

      it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/Secret-Detection], variables: { 'secret-detection-0': { 'SECRET_DETECTION_EXCLUDED_PATHS' => '', 'SECRET_DETECTION_HISTORIC_SCAN' => 'false' } }
    end

    context 'when action contains variables overriding predefined ones' do
      let(:actions) { [{ scan: 'sast', variables: { SAST_EXCLUDED_ANALYZERS: 'semgrep', 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp, other_location' } }] }

      it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/SAST], variables: { 'sast-0': { 'DEFAULT_SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp', 'SAST_EXCLUDED_ANALYZERS' => 'semgrep', 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp, other_location', 'ADVANCED_SAST_PARTIAL_SCAN' => 'false' } }

      it 'allows passing variables from the action into configuration service' do
        expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
          expect(ci_configuration_service).to receive(:execute).once
            .with(actions.first, { 'DEFAULT_SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp', 'SAST_EXCLUDED_ANALYZERS' => 'semgrep', 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp, other_location', 'ADVANCED_SAST_PARTIAL_SCAN' => 'false' }, context, 0).and_call_original
        end

        subject
      end
    end

    context 'when action contains the SECRET_DETECTION_HISTORIC_SCAN variable' do
      let(:actions) { [{ scan: 'secret_detection', variables: { SECRET_DETECTION_HISTORIC_SCAN: 'false' } }] }
      let(:branch) { project.default_branch }
      let(:service) { described_class.new(context, branch: branch, pipeline_source: pipeline_source) }

      context 'when the calculated SECRET_DETECTION_HISTORIC_SCAN would be true' do
        it 'sets the value provided from action variables' do
          expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
            expect(ci_configuration_service).to receive(:execute).once
              .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' }, context, 0).and_call_original
          end

          subject
        end
      end

      context 'when the calculated SECRET_DETECTION_HISTORIC_SCAN would be false' do
        let(:actions) { [{ scan: 'secret_detection', variables: { SECRET_DETECTION_HISTORIC_SCAN: 'true' } }] }

        before do
          pipeline = create(:ci_pipeline, project: project, user: user, source: :security_orchestration_policy, sha: project.commit(branch).sha, ref: branch)
          create(:security_scan, :latest_successful, project: project, pipeline: pipeline, scan_type: 'secret_detection',
            build: create(:ci_build, pipeline: pipeline))
        end

        it 'sets the value provided from action variables' do
          expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
            expect(ci_configuration_service).to receive(:execute).once
              .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'true', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' }, context, 0).and_call_original
          end

          subject
        end
      end
    end

    context 'when actions does not contain the SECRET_DETECTION_HISTORIC_SCAN variable' do
      let(:actions) { [{ scan: 'secret_detection', variables: {} }] }
      let(:service) { described_class.new(context, branch: project.default_branch_or_main, pipeline_source: pipeline_source) }

      context 'when scan is added to regular pipeline' do
        it 'sets the value with predefined SECRET_DETECTION_HISTORIC_SCAN value (false)' do
          expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
            expect(ci_configuration_service).to receive(:execute).once
              .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' }, context, 0).and_call_original
          end

          subject
        end
      end

      context 'when scan is added to security_orchestration_policy pipeline (from scheduled scan execution policy)' do
        let(:pipeline) { create(:ci_pipeline, sha: current_sha, project: project, ref: project.default_branch_or_main, source: :security_orchestration_policy) }
        let(:current_sha) { project.repository.commit(project.default_branch_or_main)&.sha }
        let(:previous_sha) { OpenSSL::Digest.hexdigest('SHA256', 'previous') }
        let(:pipeline_source) { :security_orchestration_policy }

        context 'when no previous pipeline was executed for that source' do
          it 'sets the value for SECRET_DETECTION_HISTORIC_SCAN to true' do
            expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
              expect(ci_configuration_service).to receive(:execute).once
                .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'true', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' }, context, 0).and_call_original
            end

            subject
          end
        end

        context 'when there is a pipeline was executed for that source' do
          let!(:previous_pipeline) { create(:ci_pipeline, project: project, sha: previous_sha, ref: project.default_branch_or_main, source: :security_orchestration_policy) }
          let!(:security_scan) do
            create(:security_scan, build: create(:ci_build, pipeline: previous_pipeline), status: :succeeded,
              scan_type: 'secret_detection', project: project, pipeline: previous_pipeline)
          end

          it 'sets the value for SECRET_DETECTION_LOG_OPTIONS to propper range' do
            expect_next_instance_of(::Security::SecurityOrchestrationPolicies::CiConfigurationService) do |ci_configuration_service|
              expect(ci_configuration_service).to receive(:execute).once
                .with(actions.first, { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_EXCLUDED_PATHS' => '', 'SECRET_DETECTION_LOG_OPTIONS' => "#{previous_sha}..#{current_sha}" }, context, 0).and_call_original
            end

            subject
          end
        end
      end
    end

    context 'when there are multiple actions' do
      let(:actions) do
        [
          { scan: 'secret_detection' },
          { scan: 'dast', scanner_profile: 'Scanner Profile', site_profile: 'Site Profile' },
          { scan: 'cluster_image_scanning' },
          { scan: 'container_scanning' },
          { scan: 'sast' }
        ]
      end

      it_behaves_like 'creates scan jobs',
        on_demand_jobs: %i[dast-on-demand-0],
        pipeline_scan_job_templates: %w[Jobs/Secret-Detection Jobs/Container-Scanning Jobs/SAST],
        variables: { 'container-scanning-1': {}, 'dast-on-demand-0': {}, 'sast-2': { 'DEFAULT_SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp', 'SAST_EXCLUDED_ANALYZERS' => '', 'SAST_EXCLUDED_PATHS' => '$DEFAULT_SAST_EXCLUDED_PATHS', 'ADVANCED_SAST_PARTIAL_SCAN' => 'false' }, 'secret-detection-0': { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' } }
    end

    context 'when there are valid and invalid actions' do
      let(:actions) do
        [
          { scan: 'secret_detection' },
          { scan: 'invalid' }
        ]
      end

      it_behaves_like 'creates scan jobs', pipeline_scan_job_templates: %w[Jobs/Secret-Detection], variables: { 'secret-detection-0': { 'SECRET_DETECTION_HISTORIC_SCAN' => 'false', 'SECRET_DETECTION_EXCLUDED_PATHS' => '' } }
    end

    it_behaves_like 'policy metrics with logging', described_class::HISTOGRAM do
      let(:actions) { [{ scan: 'container_scanning' }] }
      let(:expected_logged_data) do
        {
          "class" => described_class.name,
          "duration" => kind_of(Float),
          "project_id" => project.id,
          "action_count" => 1
        }
      end
    end
  end
end
