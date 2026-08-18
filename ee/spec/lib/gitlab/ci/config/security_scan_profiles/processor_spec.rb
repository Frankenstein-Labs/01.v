# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Config::SecurityScanProfiles::Processor, feature_category: :security_policy_management do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, :small_repo, group: namespace) }
  let_it_be(:scan_profile_sast) do
    create(:security_scan_profile, namespace: namespace, name: 'SAST Profile', scan_type: :sast, projects: [project])
  end

  let_it_be(:scan_profile_secret_detection) do
    create(:security_scan_profile,
      namespace: namespace,
      name: 'Secret Detection Profile',
      scan_type: :secret_detection,
      projects: [project]
    )
  end

  let(:config) { { image: 'image:1.0.0' } }
  let(:ref) { "refs/heads/#{project.default_branch}" }
  let(:source) { :push }
  let(:scan_profile_context) do
    Gitlab::Ci::Pipeline::SecurityScanProfiles::PipelineContext.new(
      project: project,
      ref: ref,
      pipeline_source: source
    )
  end

  let(:ci_context) do
    Gitlab::Ci::Config::External::Context.new(project: project).tap do |ctx|
      ctx.scan_profile_context = scan_profile_context
    end
  end

  subject(:perform_service) { described_class.new(config, ci_context, ref, source).perform }

  shared_examples 'does not modify the config' do
    it 'returns the original config unchanged' do
      expect(perform_service).to eq(config)
    end
  end

  shared_examples 'stage insertion behavior' do
    context 'when application-security-testing stage is already defined' do
      let(:config) { { stages: %w[build application-security-testing deploy], image: 'image:1.0.0' } }

      it 'does not duplicate the stage' do
        expect(perform_service[:stages].count('application-security-testing')).to eq(1)
      end

      it 'preserves existing stage order' do
        expect(perform_service[:stages]).to eq(%w[build application-security-testing deploy])
      end
    end

    context 'when build stage is available' do
      let(:config) { { stages: %w[build test deploy], image: 'image:1.0.0' } }

      it 'inserts application-security-testing stage after build' do
        expect(perform_service[:stages]).to eq(%w[build application-security-testing test deploy])
      end
    end

    context 'when build stage is not available' do
      let(:config) { { stages: %w[test deploy], image: 'image:1.0.0' } }

      it 'prepends application-security-testing stage' do
        expect(perform_service[:stages]).to eq(%w[application-security-testing test deploy])
      end
    end

    context 'when .pre stage is available without build' do
      let(:config) { { stages: %w[.pre test deploy], image: 'image:1.0.0' } }

      it 'inserts application-security-testing stage after .pre' do
        expect(perform_service[:stages]).to eq(%w[.pre application-security-testing test deploy])
      end
    end

    context 'when both .pre and build stages are available' do
      let(:config) { { stages: %w[.pre build test deploy], image: 'image:1.0.0' } }

      it 'inserts application-security-testing stage after build (later of the two)' do
        expect(perform_service[:stages]).to eq(%w[.pre build application-security-testing test deploy])
      end
    end

    context 'when stages are invalid' do
      let(:config) { { stages: { stages: %w[build test deploy] } } }

      it_behaves_like 'does not modify the config'
    end
  end

  context 'when feature is not licensed' do
    let_it_be(:default_branch_trigger) do
      create(:security_scan_profile_trigger, namespace: namespace, scan_profile: scan_profile_sast)
    end

    it_behaves_like 'does not modify the config'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(security_scan_profiles: true)
    end

    context 'when scan_profile_context is not provided in context' do
      let(:ci_context) { Gitlab::Ci::Config::External::Context.new(project: project) }

      it_behaves_like 'does not modify the config'
    end

    context 'when no scan profile triggers exist' do
      it_behaves_like 'does not modify the config'
    end

    context 'when scan profile triggers exist but are not pipeline-based' do
      let_it_be(:git_push_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_secret_detection,
          trigger_type: :git_push_event)
      end

      it_behaves_like 'does not modify the config'
    end

    context 'when ref is a tag' do
      let(:ref) { 'refs/tags/v1.0.0' }

      let_it_be(:default_branch_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_sast,
          trigger_type: :default_branch_pipeline)
      end

      it_behaves_like 'does not modify the config'
    end

    context 'when ref is a non-default branch' do
      let(:ref) { 'refs/heads/feature-branch' }

      let_it_be(:default_branch_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_sast,
          trigger_type: :default_branch_pipeline)
      end

      it_behaves_like 'does not modify the config'
    end

    context 'when pipeline is for default branch' do
      let(:ref) { "refs/heads/#{project.default_branch}" }

      let!(:default_branch_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_sast,
          trigger_type: :default_branch_pipeline)
      end

      let(:sast_job_config) do
        {
          'sast-0': {
            stage: 'test',
            image: { name: '$SAST_ANALYZER_IMAGE' },
            script: ['/analyzer run'],
            artifacts: {
              access: 'developer',
              paths: ['gl-sast-report.json'],
              reports: { sast: 'gl-sast-report.json' }
            }
          }
        }
      end

      before do
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ScanPipelineService) do |service|
          allow(service).to receive(:execute).and_return({ pipeline_scan: sast_job_config })
        end
      end

      it_behaves_like 'stage insertion behavior'

      context 'when config is empty' do
        let(:config) { {} }

        it 'adds a workflow rule and the scan job' do
          result = perform_service

          expect(result).to include(workflow: { rules: [{ when: 'always' }] })
          expect(result.keys).to include(:'sast-0')
        end
      end

      context 'when config has no stages defined' do
        let(:config) { { image: 'image:1.0.0' } }

        it 'uses default stages and inserts application-security-testing with correct job stage' do
          result = perform_service

          expect(result[:stages]).to include('application-security-testing')
          expect(result[:'sast-0'][:stage]).to eq('application-security-testing')
        end
      end

      it 'sets GITLAB_ADVANCED_SAST_ENABLED variable' do
        expect(perform_service[:variables]).to include('GITLAB_ADVANCED_SAST_ENABLED' => 'true')
      end

      context 'when config already has variables' do
        let(:config) { { image: 'image:1.0.0', variables: { 'EXISTING_VAR' => 'value' } } }

        it 'merges GITLAB_ADVANCED_SAST_ENABLED with existing variables' do
          expect(perform_service[:variables]).to include(
            'EXISTING_VAR' => 'value',
            'GITLAB_ADVANCED_SAST_ENABLED' => 'true'
          )
        end
      end

      context 'when config already has jobs with same names' do
        let(:config) do
          {
            stages: %w[build test deploy],
            image: 'image:1.0.0',
            'sast-0': {
              rules: [{ if: '$CI_COMMIT_BRANCH == "develop"' }],
              needs: [{ job: 'build-job', artifacts: true }]
            }
          }
        end

        it 'deep merges policy config with existing job config' do
          result = perform_service

          # deep_merge preserves existing keys while adding new ones
          expect(result[:'sast-0']).to include(
            rules: [{ if: '$CI_COMMIT_BRANCH == "develop"' }],
            needs: [{ job: 'build-job', artifacts: true }],
            script: ['/analyzer run'],
            stage: 'application-security-testing'
          )
        end
      end

      context 'when only merge_request_pipeline triggers exist' do
        let!(:default_branch_trigger) { nil }

        let!(:mr_trigger) do
          create(:security_scan_profile_trigger,
            namespace: namespace,
            scan_profile: scan_profile_sast,
            trigger_type: :merge_request_pipeline)
        end

        it_behaves_like 'does not modify the config'
      end
    end

    context 'when pipeline is for merge request' do
      let(:source) { :merge_request_event }
      let(:ref) { 'refs/heads/feature-branch' }

      let!(:mr_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_sast,
          trigger_type: :merge_request_pipeline)
      end

      let(:sast_job_config) do
        {
          'sast-0': {
            stage: 'test',
            image: { name: '$SAST_ANALYZER_IMAGE' },
            script: ['/analyzer run'],
            artifacts: {
              access: 'developer',
              paths: ['gl-sast-report.json'],
              reports: { sast: 'gl-sast-report.json' }
            }
          }
        }
      end

      before do
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ScanPipelineService) do |service|
          allow(service).to receive(:execute).and_return({ pipeline_scan: sast_job_config })
        end
      end

      it 'processes merge request pipeline triggers' do
        result = perform_service

        expect(result.keys).to include(:'sast-0')
        expect(result[:'sast-0'][:stage]).to eq('application-security-testing')
      end

      context 'when ref is a merge ref' do
        let(:ref) { 'refs/merge-requests/123/head' }

        it 'still processes merge request pipeline triggers' do
          expect(perform_service.keys).to include(:'sast-0')
        end
      end

      context 'when only default_branch_pipeline triggers exist' do
        let!(:mr_trigger) { nil }

        let!(:default_branch_trigger) do
          create(:security_scan_profile_trigger,
            namespace: namespace,
            scan_profile: scan_profile_sast,
            trigger_type: :default_branch_pipeline)
        end

        it_behaves_like 'does not modify the config'
      end
    end

    context 'when stages after processing equal default stages' do
      let(:config) { { stages: %w[.pre build test deploy .post], image: 'image:1.0.0' } }

      let_it_be(:default_branch_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_sast,
          trigger_type: :default_branch_pipeline)
      end

      before do
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ScanPipelineService) do |service|
          allow(service).to receive(:execute).and_return({ pipeline_scan: {} })
        end
      end

      it 'returns config without explicit stages' do
        result = perform_service

        expect(result).not_to have_key(:stages)
      end
    end

    context 'when multiple scan profiles with triggers exist' do
      let_it_be(:sast_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_sast,
          trigger_type: :default_branch_pipeline)
      end

      let_it_be(:secret_detection_trigger) do
        create(:security_scan_profile_trigger,
          namespace: namespace,
          scan_profile: scan_profile_secret_detection,
          trigger_type: :default_branch_pipeline)
      end

      let(:multi_job_config) do
        {
          'sast-0': {
            stage: 'test',
            image: { name: '$SAST_ANALYZER_IMAGE' },
            script: ['/analyzer run'],
            artifacts: {
              access: 'developer',
              paths: ['gl-sast-report.json'],
              reports: { sast: 'gl-sast-report.json' }
            },
            _security_metadata_context: { profile_id: scan_profile_sast.id }
          },
          'secret-detection-0': {
            stage: 'test',
            image: '$SECURE_ANALYZERS_PREFIX/secrets:$SECRETS_ANALYZER_VERSION',
            script: ['/analyzer run'],
            artifacts: {
              access: 'developer',
              paths: ['gl-secret-detection-report.json'],
              reports: { secret_detection: 'gl-secret-detection-report.json' }
            },
            _security_metadata_context: { profile_id: scan_profile_secret_detection.id }
          }
        }
      end

      before do
        allow_next_instance_of(::Security::SecurityOrchestrationPolicies::ScanPipelineService) do |service|
          allow(service).to receive(:execute).and_return({ pipeline_scan: multi_job_config })
        end
      end

      it 'includes all scan jobs' do
        result = perform_service

        expect(result.keys).to include(:'sast-0', :'secret-detection-0')
        expect(result[:'sast-0'][:stage]).to eq('application-security-testing')
        expect(result[:'secret-detection-0'][:stage]).to eq('application-security-testing')
      end

      it 'strips _security_metadata_context from the final config' do
        result = perform_service

        expect(result[:'sast-0']).not_to have_key(:_security_metadata_context)
        expect(result[:'secret-detection-0']).not_to have_key(:_security_metadata_context)
      end

      it 'collects injected job names on the scan profile context' do
        perform_service

        expect(scan_profile_context.job_injected?(:'sast-0')).to be true
        expect(scan_profile_context.job_injected?(:'secret-detection-0')).to be true
        expect(scan_profile_context.job_injected?(:image)).to be false
      end

      it 'maps injected job names to their profile IDs via metadata' do
        perform_service

        expect(scan_profile_context.profile_id_for_job(:'sast-0')).to eq(scan_profile_sast.id)
        expect(scan_profile_context.profile_id_for_job(:'secret-detection-0')).to eq(scan_profile_secret_detection.id)
        expect(scan_profile_context.profile_id_for_job(:image)).to be_nil
      end

      context 'when pipeline_scan contains non-Hash values' do
        let(:multi_job_config) do
          {
            'sast-0': {
              stage: 'test',
              image: { name: '$SAST_ANALYZER_IMAGE' },
              script: ['/analyzer run'],
              _security_metadata_context: { profile_id: scan_profile_sast.id }
            },
            'frozen-job': 'some_string_value'
          }
        end

        it 'preserves non-Hash job config values unchanged' do
          result = perform_service

          expect(result[:'sast-0']).not_to have_key(:_security_metadata_context)
          expect(result[:'frozen-job']).to eq('some_string_value')
        end
      end

      context 'when injected jobs use reserved stages (.pre, .post)' do
        let(:multi_job_config) do
          {
            'resolve-job': {
              stage: '.pre',
              script: ['echo resolve']
            },
            'sast-0': {
              stage: 'test',
              image: { name: '$SAST_ANALYZER_IMAGE' },
              script: ['/analyzer run']
            },
            'cleanup-job': {
              stage: '.post',
              script: ['echo cleanup']
            }
          }
        end

        it 'preserves .pre and .post stages while overriding other stages' do
          result = perform_service

          expect(result[:'resolve-job'][:stage]).to eq('.pre')
          expect(result[:'cleanup-job'][:stage]).to eq('.post')
          expect(result[:'sast-0'][:stage]).to eq('application-security-testing')
        end
      end
    end

    context 'when injecting CI variables from a trigger configuration' do
      let(:ref) { "refs/heads/#{project.default_branch}" }
      let(:env_var_value) { 'abc..123..def' }

      let!(:secret_detection_trigger) do
        create(:security_scan_profile_trigger, namespace: namespace, scan_profile: scan_profile_secret_detection)
      end

      context 'when a trigger contributes CI variables' do
        before do
          allow(Security::ScanProfiles::Configuration::CiVariables)
            .to receive(:build).and_return('TEST_VARIABLE' => env_var_value)
        end

        it 'injects the trigger variables into the generated secret-detection job' do
          expect(perform_service[:'secret-detection-profile-0'][:variables]).to include(TEST_VARIABLE: env_var_value)
        end
      end

      context 'when a trigger contributes no CI variables' do
        it 'does not inject any mapped variable' do
          expect(perform_service[:'secret-detection-profile-0'][:variables]).not_to include(:TEST_VARIABLE)
        end
      end
    end
  end
end
