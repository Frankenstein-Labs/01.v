# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Variables::Builder::ScanExecutionPolicies, feature_category: :security_policy_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:namespace) { create(:group) }
  let_it_be(:project) { create(:project, :small_repo, group: namespace) }
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let(:job_name) { 'build-job' }
  let(:job) { build(:ci_build, name: job_name, pipeline: pipeline, user: user) }
  let(:licensed_feature) { true }
  let(:builder) { described_class.new(pipeline) }

  before do
    stub_licensed_features(security_orchestration_policies: licensed_feature)
  end

  describe '#variables' do
    let(:args) { [job.name, []] }

    subject(:variables) { builder.variables(*args) }

    context 'with security policies' do
      let_it_be(:namespace_policies_project) { create(:project, :small_repo) }
      let_it_be(:namespace_security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, :namespace, namespace: namespace,
          security_policy_management_project: namespace_policies_project)
      end

      let_it_be(:policies_project) { create(:project, :small_repo, group: namespace) }
      let_it_be(:security_orchestration_policy_configuration) do
        create(:security_orchestration_policy_configuration, project: project,
          security_policy_management_project: policies_project)
      end

      let_it_be(:namespace_policy) do
        build(:scan_execution_policy, actions: [
          { scan: 'container_scanning', tags: ['runner-tag'], variables: { CS_REGISTRY_USER: 'user' } }
        ])
      end

      let_it_be(:project_policy) do
        build(:scan_execution_policy, actions: [
          { scan: 'sast', variables: { SAST_EXCLUDED_ANALYZERS: 'semgrep' } },
          { scan: 'secret_detection', variables: { SECRET_DETECTION_HISTORIC_SCAN: 'true' } },
          { scan: 'sast_iac', tags: ['runner-tag'], variables: { SAST_IMAGE_SUFFIX: '-fips' } },
          { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile',
            variables: { DAST_WEBSITE: 'https://my.site.com' } },
          { scan: 'dependency_scanning', tags: ['runner-tag'], variables: { DS_IMAGE_SUFFIX: '-fips' } }
        ])
      end

      let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [project_policy]) }
      let_it_be(:namespace_policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [namespace_policy]) }

      let(:job_name) { 'secret-detection-2' }

      before do
        allow_next_instance_of(Repository) do |repository|
          allow(repository).to receive(:blob_data_at).and_return(policy_yaml)
        end

        allow_next_instance_of(Repository, anything, namespace_policies_project, anything) do |repository|
          allow(repository).to receive(:blob_data_at).and_return(namespace_policy_yaml)
        end
      end

      # the suffixes get assigned in order of the actions in the policies
      where(:job_name, :expected_variables) do
        'build-job'                              | {}
        'dast-on-demand-0'                       | { 'DAST_WEBSITE' => 'https://my.site.com' }
        'container-scanning-0'                   | { 'CS_REGISTRY_USER' => 'user' }
        'brakeman-sast-1'                        | { 'SAST_EXCLUDED_ANALYZERS' => 'semgrep',
                                                     'SAST_EXCLUDED_PATHS' => '$DEFAULT_SAST_EXCLUDED_PATHS',
                                                     'DEFAULT_SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp',
                                                     'ADVANCED_SAST_PARTIAL_SCAN' => 'false' }
        'secret-detection-2'                     | { 'SECRET_DETECTION_HISTORIC_SCAN' => 'true',
                                                     'SECRET_DETECTION_EXCLUDED_PATHS' => '' }
        'kics-iac-sast-3'                        | { 'SAST_IMAGE_SUFFIX' => '-fips',
                                                     'SAST_EXCLUDED_ANALYZERS' => '',
                                                     'SAST_EXCLUDED_PATHS' => 'spec, test, tests, tmp' }
        'gemnasium-python-dependency-scanning-4' | { 'DS_IMAGE_SUFFIX' => '-fips',
                                                     'DS_EXCLUDED_PATHS' => 'spec, test, tests, tmp',
                                                     'DS_EXCLUDED_ANALYZERS' => '' }
      end

      with_them do
        it { is_expected.to match_array(expected_variables.map { |key, value| item(key: key, value: value) }) }
      end

      describe 'memoization' do
        it 'memoizes result of active_scan_variables' do
          expect_next_instance_of(::Security::SecurityOrchestrationPolicies::ScanPipelineService) do |instance|
            expect(instance).to receive(:execute).once.and_call_original
          end

          2.times do
            expect(builder.variables(job.name)).to contain_exactly(
              item(key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'true'),
              item(key: 'SECRET_DETECTION_EXCLUDED_PATHS', value: '')
            )
          end
        end
      end

      context 'when job name does not adhere to the naming convention for scan execution policies jobs' do
        %w[secret_detection secret-detection secret-detection-a secret-detection-2a invalid-0].each do |name|
          context "with job name #{name}" do
            let(:job_name) { name }

            it { is_expected.to match_array([]) }
          end
        end
      end

      context 'when policy is defined for scheduled pipelines' do
        let_it_be(:project_policy) do
          build(:scan_execution_policy, :with_schedule, actions: [
            { scan: 'sast', variables: { SAST_EXCLUDED_ANALYZERS: 'semgrep' } }
          ])
        end

        let_it_be(:namespace_policy) do
          build(:scan_execution_policy, :with_schedule, actions: [
            { scan: 'container_scanning', tags: ['runner-tag'], variables: { CS_REGISTRY_USER: 'user' } }
          ])
        end

        let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [project_policy]) }
        let_it_be(:namespace_policy_yaml) do
          build(:orchestration_policy_yaml, scan_execution_policy: [namespace_policy])
        end

        where(:job_name, :expected_variables_lambda) do
          'build-job'            | -> { [] }
          'container-scanning-0' | -> { [item(key: 'CS_REGISTRY_USER', value: 'user')] }
          'brakeman-sast-1'      | -> do
            [
              item(key: 'DEFAULT_SAST_EXCLUDED_PATHS', value: 'spec, test, tests, tmp'),
              item(key: 'SAST_EXCLUDED_PATHS', value: '$DEFAULT_SAST_EXCLUDED_PATHS'),
              item(key: 'SAST_EXCLUDED_ANALYZERS', value: 'semgrep'),
              item(key: 'ADVANCED_SAST_PARTIAL_SCAN', value: 'false')
            ]
          end
        end

        with_them do
          it do
            is_expected.to match_array(expected_variables_lambda.call)
          end
        end
      end

      context 'when feature is not licensed' do
        let(:licensed_feature) { false }

        it { is_expected.to match_array([]) }
      end

      context 'when job name is nil' do
        let(:job_name) { nil }

        it { is_expected.to match_array([]) }
      end

      context 'when handling variable conflicts' do
        let_it_be(:project_policy) do
          build(:scan_execution_policy, actions: [
            { scan: 'secret_detection', variables: { SECRET_DETECTION_HISTORIC_SCAN: 'true' } }
          ])
        end

        let_it_be(:scheduled_project_policy) do
          build(:scan_execution_policy, :with_schedule, actions: [
            { scan: 'secret_detection', variables: { SECRET_DETECTION_HISTORIC_SCAN: 'true' } }
          ])
        end

        let(:job_name) { 'secret-detection-1' }

        context 'when has conflicting variables' do
          let(:yaml_variables) { [{ key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'false' }] }
          let(:args) { [job.name, yaml_variables] }

          context 'when pipeline source is push' do
            let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [project_policy]) }

            it 'enforces policy variables and overrides YAML variables' do
              is_expected.to contain_exactly(
                item(key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'true'),
                item(key: 'SECRET_DETECTION_EXCLUDED_PATHS', value: '')
              )
            end
          end

          context 'when pipeline source is scheduled sep' do
            let_it_be(:policy_yaml) do
              build(:orchestration_policy_yaml, scan_execution_policy: [scheduled_project_policy])
            end

            let(:pipeline) { create(:ci_pipeline, project: project, source: :security_orchestration_policy) }

            it 'skips conflicting policy variables and preserves YAML variables' do
              is_expected.to contain_exactly(
                item(key: 'SECRET_DETECTION_EXCLUDED_PATHS', value: '')
              )
            end
          end
        end

        context 'when does not have conflicting variables' do
          let(:yaml_variables) { [{ key: 'OTHER_VARIABLE', value: 'some_value' }] }
          let(:args) { [job.name, yaml_variables] }

          context 'when pipeline source is push' do
            let_it_be(:policy_yaml) { build(:orchestration_policy_yaml, scan_execution_policy: [project_policy]) }

            it 'enforces all policy variables' do
              is_expected.to contain_exactly(
                item(key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'true'),
                item(key: 'SECRET_DETECTION_EXCLUDED_PATHS', value: '')
              )
            end
          end

          context 'when pipeline source is scheduled sep' do
            let_it_be(:policy_yaml) do
              build(:orchestration_policy_yaml, scan_execution_policy: [scheduled_project_policy])
            end

            let(:pipeline) { create(:ci_pipeline, project: project, source: :security_orchestration_policy) }

            it 'enforces all policy variables' do
              is_expected.to contain_exactly(
                item(key: 'SECRET_DETECTION_HISTORIC_SCAN', value: 'true'),
                item(key: 'SECRET_DETECTION_EXCLUDED_PATHS', value: '')
              )
            end
          end
        end
      end
    end

    context 'without security policies' do
      it { is_expected.to match_array([]) }
    end

    def item(variable)
      ::Gitlab::Ci::Variables::Collection::Item.fabricate(variable)
    end
  end
end
