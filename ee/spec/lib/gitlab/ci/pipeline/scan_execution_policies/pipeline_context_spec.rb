# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::ScanExecutionPolicies::PipelineContext, feature_category: :security_policy_management do
  subject(:context) do
    described_class.new(project: project, ref: ref, current_user: user, source: source)
  end

  let_it_be_with_refind(:project) { create(:project, :small_repo) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let(:ref) { 'refs/heads/master' }
  let(:source) { 'push' }
  let(:pipeline) { build(:ci_pipeline, source: source, project: project, ref: ref, user: user) }

  let_it_be(:policy_files) { { Security::OrchestrationPolicyConfiguration::POLICY_PATH => '' } }
  let_it_be(:policies_repository) { create(:project, :custom_repo, files: policy_files) }
  let(:feature_licensed) { true }
  let_it_be(:security_orchestration_policy_configuration) do
    create(
      :security_orchestration_policy_configuration,
      project: project,
      security_policy_management_project: policies_repository
    )
  end

  let(:expected_metadata) do
    {
      name: 'My policy',
      sha: security_orchestration_policy_configuration.configuration_sha,
      project_id: policies_repository.id,
      variables_override: { allowed: true }
    }
  end

  let(:policy) do
    build(:scan_execution_policy, name: 'My policy', actions: [
      { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' },
      { scan: 'secret_detection' },
      { scan: 'dependency_scanning' }
    ])
  end

  let(:policy_duplicated_action) do
    build(:scan_execution_policy, name: 'My duplicated policy', actions: [{ scan: 'dependency_scanning' }])
  end

  let(:disabled_policy) do
    build(:scan_execution_policy, enabled: false, actions: [{ scan: 'sast_iac' }])
  end

  let(:inapplicable_policy) do
    build(:scan_execution_policy,
      actions: [{ scan: 'container_scanning' }],
      rules: [{ type: 'pipeline', branches: %w[other] }])
  end

  let(:policies) { [policy, policy_duplicated_action, disabled_policy, inapplicable_policy] }
  let(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: policies) }
  let!(:db_policies) do
    policies.map.with_index do |policy, index|
      create(:security_policy, :scan_execution_policy, linked_projects: [project], policy_index: index,
        security_orchestration_policy_configuration: security_orchestration_policy_configuration,
        content: policy.slice(:actions, :skip_ci, :no_pipeline))
    end
  end

  before do
    stub_licensed_features(security_orchestration_policies: feature_licensed)
    allow_next_instance_of(Repository, anything, anything, anything) do |repository|
      allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
    end
  end

  describe '#has_scan_execution_policies?' do
    subject { context.has_scan_execution_policies? }

    it { is_expected.to be(true) }

    context 'when no policies are returned' do
      let(:policies) { [] }

      it { is_expected.to be(false) }
    end

    context 'when no scan execution policies are associated with the project in the database' do
      let!(:db_policies) { [] }

      it { is_expected.to be(false) }
    end

    context 'when ref is not for a branch' do
      let(:ref) { 'master' }

      it { is_expected.to be(false) }
    end

    context 'when source is not a ci source' do
      let(:source) { 'ondemand_dast_scan' }

      it { is_expected.to be(false) }
    end

    context 'when source is nil' do
      let(:source) { nil }

      it { is_expected.to be(false) }
    end

    context 'when feature is not licensed' do
      let(:feature_licensed) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '#active_scan_execution_actions' do
    subject(:actions) { context.active_scan_execution_actions }

    it 'contains active actions with metadata' do
      expect(actions).to match_array([
        { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile',
          metadata: expected_metadata },
        { scan: 'secret_detection', metadata: expected_metadata },
        { scan: 'dependency_scanning', metadata: expected_metadata.merge(name: 'My policy') }
      ])
    end

    context 'when other policy defines the same scan with different parameters' do
      let(:policies) { [policy, other_policy] }
      let(:other_policy) do
        build(:scan_execution_policy, name: 'Other policy', actions: [
          { scan: 'dependency_scanning', variables: { 'DS_ENFORCE_NEW_ANALYZER' => 'true' } }
        ])
      end

      it 'is not deduplicated' do
        expect(actions).to match_array([
          { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile',
            metadata: expected_metadata },
          { scan: 'secret_detection', metadata: expected_metadata },
          { scan: 'dependency_scanning', metadata: expected_metadata.merge(name: 'My policy') },
          { scan: 'dependency_scanning', variables: { DS_ENFORCE_NEW_ANALYZER: 'true' },
            metadata: expected_metadata.merge(
              name: 'Other policy',
              variables_override: { allowed: true, exceptions: ["DS_ENFORCE_NEW_ANALYZER"] }
            ) }
        ])
      end
    end

    describe 'action limits' do
      let(:policies) { [policy, other_policy] }
      let(:other_policy) do
        build(:scan_execution_policy, name: 'Other policy', actions: [
          { scan: 'sast' },
          { scan: 'sast_iac' },
          { scan: 'container_scanning' }
        ])
      end

      let(:expected_other_metadata) { expected_metadata.merge(name: 'Other policy') }
      let(:action_limit) { 2 }

      before do
        allow(Gitlab::CurrentSettings).to receive(:scan_execution_policies_action_limit).and_return(action_limit)
      end

      it 'contains active actions with metadata' do
        expect(actions).to match_array([
          { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile',
            metadata: expected_metadata },
          { scan: 'secret_detection', metadata: expected_metadata },
          { scan: 'sast', metadata: expected_other_metadata },
          { scan: 'sast_iac', metadata: expected_other_metadata }
        ])
      end

      context 'when value is zero' do
        let(:action_limit) { 0 }

        it 'contains active actions with metadata' do
          expect(actions).to match_array([
            { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile',
              metadata: expected_metadata },
            { scan: 'secret_detection', metadata: expected_metadata },
            { scan: 'dependency_scanning', metadata: expected_metadata },
            { scan: 'sast', metadata: expected_other_metadata },
            { scan: 'sast_iac', metadata: expected_other_metadata },
            { scan: 'container_scanning', metadata: expected_other_metadata }
          ])
        end
      end
    end

    context 'when source is defined in the policy' do
      let(:policies) { [policy] }
      let(:policy) do
        build(:scan_execution_policy,
          name: 'My policy',
          actions: [
            { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' },
            { scan: 'secret_detection' },
            { scan: 'dependency_scanning' }
          ],
          rules: [
            { type: 'pipeline', branches: %w[master], pipeline_sources: { including: [policy_pipeline_source] } }
          ])
      end

      context 'when matches pipeline source' do
        let(:policy_pipeline_source) { source }

        it 'returns the active scan execution actions' do
          expect(context.active_scan_execution_actions).to match_array([
            { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile',
              metadata: expected_metadata },
            { scan: 'secret_detection', metadata: expected_metadata },
            { scan: 'dependency_scanning', metadata: expected_metadata }
          ])
        end
      end

      context 'when does not match pipeline source' do
        let(:policy_pipeline_source) { 'api' }

        it 'returns empty array' do
          expect(context.active_scan_execution_actions).to be_empty
        end
      end
    end
  end

  describe '#skip_ci_allowed?' do
    subject { context.skip_ci_allowed? }

    context 'when policies have no skip_ci configuration' do
      it { is_expected.to be(true) }
    end

    context 'when there are no policies' do
      let(:policies) { [] }

      it { is_expected.to be(true) }
    end

    context 'when there are multiple policies that allow skip_ci' do
      let(:policies) { [policy1, policy2] }
      let(:policy1) do
        build(:scan_execution_policy, :skip_ci_allowed, actions: [{ scan: 'secret_detection' }])
      end

      let(:policy2) do
        build(:scan_execution_policy, :skip_ci_allowed, actions: [{ scan: 'dependency_scanning' }])
      end

      it { is_expected.to be(true) }
    end

    context 'when there is a single policy that disallows skip_ci' do
      let(:policies) { [policy] }
      let(:policy) do
        build(:scan_execution_policy, :skip_ci_disallowed, actions: [{ scan: 'secret_detection' }])
      end

      it { is_expected.to be(false) }
    end

    context 'when there are multiple policies and only one disallows skip_ci' do
      let(:policies) { [policy1, policy2] }
      let(:policy1) do
        build(:scan_execution_policy, :skip_ci_disallowed, actions: [{ scan: 'secret_detection' }])
      end

      let(:policy2) do
        build(:scan_execution_policy, :skip_ci_allowed, actions: [{ scan: 'dependency_scanning' }])
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#no_pipeline_allowed?' do
    subject { context.no_pipeline_allowed? }

    context 'when policies no have no_pipeline configuration' do
      it { is_expected.to be(true) }
    end

    context 'when there are no policies' do
      let(:policies) { [] }

      it { is_expected.to be(true) }
    end

    context 'when there are multiple policies that allow no_pipeline' do
      let(:policies) { [policy1, policy2] }
      let(:policy1) do
        build(:scan_execution_policy, :no_pipeline_allowed, actions: [{ scan: 'secret_detection' }])
      end

      let(:policy2) do
        build(:scan_execution_policy, :no_pipeline_allowed, actions: [{ scan: 'dependency_scanning' }])
      end

      it { is_expected.to be(true) }
    end

    context 'when there is a single policy that disallows no_pipeline' do
      let(:policies) { [policy] }
      let(:policy) do
        build(:scan_execution_policy, :no_pipeline_disallowed, actions: [{ scan: 'secret_detection' }])
      end

      it { is_expected.to be(false) }
    end

    context 'when there are multiple policies and only one disallows no_pipeline' do
      let(:policies) { [policy1, policy2] }
      let(:policy1) do
        build(:scan_execution_policy, :no_pipeline_disallowed, actions: [{ scan: 'secret_detection' }])
      end

      let(:policy2) do
        build(:scan_execution_policy, :no_pipeline_allowed, actions: [{ scan: 'dependency_scanning' }])
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#job_injected?' do
    it 'returns the collected job names' do
      context.collect_injected_job_names_with_metadata({
        job1: { some_key: 'value' },
        'job-2': { some_other_key: 'other value ' }
      })

      expect(context.job_injected?('job1')).to be(true)
      expect(context.job_injected?('job-2')).to be(true)
      expect(context.job_injected?('job3')).to be(false)
    end
  end

  describe '#job_options' do
    it 'returns the metadata corresponding to the collected jobs, ignoring other attributes' do
      metadata_key = ::Security::SecurityOrchestrationPolicies::CiConfigurationMetadata::METADATA_KEY

      context.collect_injected_job_names_with_metadata({
        job1: { metadata_key => { some_key: 'value' }, some_other_key: 'value2' },
        'job-2': { some_other_key: 'other value' }
      })

      expect(context.job_options('job1')).to eq(some_key: 'value')
      expect(context.job_options('job-2')).to be_nil
      expect(context.job_options('job3')).to be_nil
    end

    context 'when source is security_orchestration_policy' do
      let(:source) { :security_orchestration_policy }

      it 'returns variables_override with allowed: true and no exceptions' do
        expect(context.job_options('job1')).to eq(variables_override: { allowed: true })
      end

      context 'when policy name is provided' do
        subject(:context) do
          described_class.new(
            project: project, ref: ref, current_user: user, source: source,
            policy_name: 'My scheduled policy'
          )
        end

        it 'includes the policy name in the returned metadata' do
          expect(context.job_options('job1')).to eq(
            variables_override: { allowed: true },
            name: 'My scheduled policy'
          )
        end
      end

      context 'when scan_variables_map is provided' do
        subject(:context) do
          described_class.new(
            project: project, ref: ref, current_user: user, source: source,
            policy_name: 'My policy',
            scan_variables_map: {
              'secret-detection-0': { 'SECRET_DETECTION_HISTORIC_SCAN' => 'true',
                                      'SECRET_DETECTION_EXCLUDED_PATHS' => '' },
              'sast-1': { 'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp' }
            }
          )
        end

        it 'returns per-job exceptions from the variables map' do
          expect(context.job_options('secret-detection-0')).to eq(
            variables_override: {
              allowed: true,
              exceptions: %w[SECRET_DETECTION_HISTORIC_SCAN SECRET_DETECTION_EXCLUDED_PATHS]
            },
            name: 'My policy'
          )

          expect(context.job_options('sast-1')).to eq(
            variables_override: {
              allowed: true,
              exceptions: %w[SAST_EXCLUDED_PATHS]
            },
            name: 'My policy'
          )
        end

        it 'returns no exceptions for jobs not in the map' do
          expect(context.job_options('unknown-job')).to eq(
            variables_override: { allowed: true },
            name: 'My policy'
          )
        end
      end
    end

    context 'when source is ondemand_dast_scan' do
      let(:source) { :ondemand_dast_scan }

      context 'when scan_variables_map is provided' do
        subject(:context) do
          described_class.new(
            project: project, ref: ref, current_user: user, source: source,
            policy_name: 'DAST Policy',
            scan_variables_map: {
              'dast-on-demand-0': { 'DAST_WEBSITE' => 'https://example.com' }
            }
          )
        end

        it 'returns variables_override with exceptions for DAST job' do
          expect(context.job_options('dast-on-demand-0')).to eq(
            variables_override: {
              allowed: true,
              exceptions: %w[DAST_WEBSITE]
            },
            name: 'DAST Policy'
          )
        end

        it 'returns variables_override without exceptions for jobs not in the map' do
          expect(context.job_options('other-job')).to eq(
            variables_override: { allowed: true },
            name: 'DAST Policy'
          )
        end
      end

      context 'when scan_variables_map is not provided' do
        it 'falls through to the injected job check' do
          expect(context.job_options('dast-on-demand-0')).to be_nil
        end
      end
    end
  end
end
