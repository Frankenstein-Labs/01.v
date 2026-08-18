# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::CreatePipelineService, feature_category: :security_policy_management do
  include RepoHelpers

  let(:opts) { {} }
  let_it_be(:group) { create(:group) }
  let_it_be_with_refind(:project) { create(:project, :repository, :auto_devops_disabled, group: group) }
  let_it_be_with_reload(:compliance_project) { create(:project, :empty_repo, group: group) }
  let_it_be(:user) { create(:user, developer_of: [project, compliance_project]) }

  let(:namespace_policy_content) { { namespace_policy_job: { stage: 'build', script: 'namespace script' } } }
  let(:namespace_policy_file) { 'namespace-policy.yml' }
  let(:namespace_policy) do
    build(:pipeline_execution_policy,
      content: { include: [{
        project: compliance_project.full_path,
        file: namespace_policy_file,
        ref: compliance_project.default_branch_or_main
      }] })
  end

  let(:namespace_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [namespace_policy])
  end

  let_it_be_with_reload(:namespace_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be(:namespace_configuration) do
    create(:security_orchestration_policy_configuration,
      project: nil, namespace: group, security_policy_management_project: namespace_policies_project)
  end

  let(:project_policy_content) { { project_policy_job: { script: 'project script' } } }
  let(:project_policy_file) { 'project-policy.yml' }
  let(:project_policy) do
    build(:pipeline_execution_policy,
      content: { include: [{
        project: compliance_project.full_path,
        file: project_policy_file,
        ref: compliance_project.default_branch_or_main
      }] })
  end

  let(:project_policy_yaml) do
    build(:orchestration_policy_yaml, pipeline_execution_policy: [project_policy])
  end

  let_it_be_with_reload(:project_policies_project) { create(:project, :empty_repo, group: group) }

  let_it_be(:project_configuration) do
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
          -echo 'test'
    YAML
  end

  let(:service) { described_class.new(project, user, { ref: 'master' }) }

  around do |example|
    create_and_delete_files(project, { '.gitlab-ci.yml' => project_ci_yaml }) do
      create_and_delete_files(
        project_policies_project, { '.gitlab/security-policies/policy.yml' => project_policy_yaml }
      ) do
        create_and_delete_files(
          namespace_policies_project, { '.gitlab/security-policies/policy.yml' => namespace_policy_yaml }
        ) do
          create_and_delete_files(
            compliance_project, {
              project_policy_file => project_policy_content.to_yaml,
              namespace_policy_file => namespace_policy_content.to_yaml
            }
          ) do
            example.run
          end
        end
      end
    end
  end

  before do
    stub_licensed_features(security_orchestration_policies: true)
  end

  describe '#execute' do
    subject(:execute) do
      service.execute(:push, **opts)
    end

    context 'with security policy' do
      let(:scan_execution_policy) do
        build(:scan_execution_policy, actions: [
          { scan: 'secret_detection' },
          { scan: 'sast_iac' },
          { scan: 'container_scanning' },
          { scan: 'sast' },
          { scan: 'dast', site_profile: '', scanner_profile: '' }
        ])
      end

      let(:project_policy_yaml) do
        build(:orchestration_policy_yaml,
          pipeline_execution_policy: [project_policy],
          scan_execution_policy: [scan_execution_policy])
      end

      before do
        create(:security_policy, :scan_execution_policy, linked_projects: [project],
          content: scan_execution_policy.slice(:actions),
          security_orchestration_policy_configuration: project_configuration)
      end

      it 'sets correct build and pipeline source for jobs' do
        expected_sources = {
          "build" => nil,
          "namespace_policy_job" => "pipeline_execution_policy",
          "rspec" => nil,
          "dast-on-demand-0" => "scan_execution_policy",
          "secret-detection-0" => "scan_execution_policy",
          "kics-iac-sast-1" => "scan_execution_policy",
          "container-scanning-2" => "scan_execution_policy",
          "semgrep-sast-3" => "scan_execution_policy",
          "project_policy_job" => "pipeline_execution_policy"
        }

        pipeline = nil
        expect do
          pipeline = execute.payload
        end.to change { Ci::BuildSource.count }.by(9)

        pipeline.builds.each do |build|
          source = Ci::BuildSource.find_by(build_id: build.id, project_id: project.id)
          expected = expected_sources[build.name] || pipeline.source
          expect(source.source).to eq(expected),
            "expected source for build #{build.name} to match #{expected}, but it was #{source.source}"
        end
      end

      it 'does not set security_scan_profiles source for non-profile pipelines' do
        pipeline = execute.payload

        pipeline.builds.each do |build|
          source = Ci::BuildSource.find_by!(build_id: build.id, project_id: project.id)
          expect(source.source).not_to eq('security_scan_profiles'),
            "expected build #{build.name} not to have security_scan_profiles source"
        end
      end
    end

    context 'with security scan profile pipeline (dedicated)' do
      let(:service) { described_class.new(project, user, { ref: 'master' }) }

      subject(:execute) do
        service.execute(:push, **opts)
      end

      before do
        allow_next_instance_of(Gitlab::Ci::ProjectConfig) do |config|
          allow(config).to receive(:source).and_return(:security_scan_profiles_source)
        end
      end

      it 'sets security_scan_profiles source for non-policy jobs' do
        pipeline = execute.payload
        sources = pipeline.builds.map do |build|
          Ci::BuildSource.find_by!(build_id: build.id, project_id: project.id).source
        end

        non_policy_sources = sources - %w[pipeline_execution_policy scan_execution_policy]
        expect(non_policy_sources).to be_present
        expect(non_policy_sources).to all(eq('security_scan_profiles'))
      end
    end

    context 'with mixed pipeline (repository YAML + profile-injected jobs)' do
      let(:scan_profile_id) { 42 }

      let(:metadata_key) { ::Security::SecurityOrchestrationPolicies::CiConfigurationMetadata::METADATA_KEY }

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
            },
            metadata_key => { profile_id: scan_profile_id }
          }
        }
      end

      before do
        stub_licensed_features(security_orchestration_policies: true, security_scan_profiles: true)

        allow_next_instance_of(::Security::ScanProfiles::PipelineEligibilityService) do |service|
          allow(service).to receive_messages(eligible?: true, applicable_profiles_triggers: [])
        end

        # rubocop:disable RSpec/AnyInstanceOf -- multiple instances created during pipeline creation
        allow_any_instance_of(::Security::SecurityOrchestrationPolicies::ScanPipelineService).to receive(:execute)
          .and_return({ pipeline_scan: sast_job_config, on_demand: {}, variables: {} })
        # rubocop:enable RSpec/AnyInstanceOf
      end

      it 'sets security_scan_profiles source only for profile-injected jobs' do
        pipeline = execute.payload
        names = %w[build rspec]

        profile_injected_builds = pipeline.builds.select { |b| b.name == 'sast-0' }
        yaml_builds = pipeline.builds.select { |b| names.include?(b.name) }

        expect(profile_injected_builds).not_to be_empty
        expect(yaml_builds).not_to be_empty

        profile_injected_builds.each do |build|
          source = Ci::BuildSource.find_by!(build_id: build.id, project_id: project.id)
          expect(source.source).to eq('security_scan_profiles'),
            "expected profile-injected build #{build.name} to have security_scan_profiles source, " \
              "but it was #{source.source}"
        end

        yaml_builds.each do |build|
          source = Ci::BuildSource.find_by!(build_id: build.id, project_id: project.id)
          expect(source.source).not_to eq('security_scan_profiles'),
            "expected YAML build #{build.name} not to have security_scan_profiles source"
        end
      end

      it 'persists profile_id mappings to Redis keyed by job name' do
        pipeline = execute.payload
        key = ::Gitlab::Ci::Pipeline::SecurityScanProfiles::ScanProfileMappingStore.redis_key(pipeline.id)
        stored = ::Gitlab::Redis::SharedState.with { |redis| redis.hgetall(key) }

        expect(stored['sast-0']).to eq(scan_profile_id.to_s)
        expect(stored).not_to have_key('build')
      end
    end
  end
end
