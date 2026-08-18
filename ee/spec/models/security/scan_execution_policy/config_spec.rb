# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicy::Config, feature_category: :security_policy_management do
  let_it_be(:policy_files) { { Security::OrchestrationPolicyConfiguration::POLICY_PATH => '' } }
  let_it_be(:security_policy_project) { create(:project, :custom_repo, files: policy_files) }
  let_it_be(:security_orchestration_policy_configuration) do
    create(:security_orchestration_policy_configuration, security_policy_management_project: security_policy_project)
  end

  let(:config) { described_class.new(**params) }
  let(:params) { { policy: policy, configuration: security_orchestration_policy_configuration } }

  describe '#actions' do
    subject(:actions) { config.actions }

    let(:policy) { build(:scan_execution_policy, name: 'Policy name', actions: policy_actions) }

    let(:expected_base_metadata) do
      {
        name: 'Policy name',
        project_id: security_policy_project.id,
        sha: security_orchestration_policy_configuration.configuration_sha
      }
    end

    context 'when action has no custom variables' do
      let(:policy_actions) { [{ scan: 'secret_detection' }] }

      it 'returns metadata with variables_override allowing all overrides' do
        expect(actions).to eq([{
          scan: 'secret_detection',
          metadata: expected_base_metadata.merge(
            variables_override: { allowed: true }
          )
        }])
      end
    end

    context 'when action defines custom variables' do
      let(:policy_actions) { [{ scan: 'sast', variables: { 'SAST_DISABLED' => 'false' } }] }

      it 'returns metadata with variables_override listing variable keys as exceptions' do
        expect(actions).to eq([{
          scan: 'sast',
          variables: { 'SAST_DISABLED' => 'false' },
          metadata: expected_base_metadata.merge(
            variables_override: { allowed: true, exceptions: ['SAST_DISABLED'] }
          )
        }])
      end
    end

    context 'when action defines multiple custom variables' do
      let(:policy_actions) do
        [{ scan: 'dependency_scanning', variables: { 'DS_EXCLUDED_PATHS' => 'vendor', 'DS_MAX_DEPTH' => '2' } }]
      end

      it 'includes all variable keys as exceptions' do
        expect(actions).to eq([{
          scan: 'dependency_scanning',
          variables: { 'DS_EXCLUDED_PATHS' => 'vendor', 'DS_MAX_DEPTH' => '2' },
          metadata: expected_base_metadata.merge(
            variables_override: { allowed: true, exceptions: %w[DS_EXCLUDED_PATHS DS_MAX_DEPTH] }
          )
        }])
      end
    end

    context 'when policy has multiple actions with different variables' do
      let(:policy_actions) do
        [
          { scan: 'sast', variables: { 'SAST_DISABLED' => 'false' } },
          { scan: 'secret_detection' }
        ]
      end

      it 'builds independent metadata for each action' do
        expect(actions).to eq([
          {
            scan: 'sast',
            variables: { 'SAST_DISABLED' => 'false' },
            metadata: expected_base_metadata.merge(
              variables_override: { allowed: true, exceptions: ['SAST_DISABLED'] }
            )
          },
          {
            scan: 'secret_detection',
            metadata: expected_base_metadata.merge(
              variables_override: { allowed: true }
            )
          }
        ])
      end
    end

    context 'when configuration is nil' do
      let(:params) { { policy: policy, configuration: nil } }
      let(:policy_actions) { [{ scan: 'sast', variables: { 'SAST_DISABLED' => 'false' } }] }

      it 'returns metadata with only name and variables_override' do
        expect(actions).to eq([{
          scan: 'sast',
          variables: { 'SAST_DISABLED' => 'false' },
          metadata: {
            name: 'Policy name',
            variables_override: { allowed: true, exceptions: ['SAST_DISABLED'] }
          }
        }])
      end
    end
  end

  describe '#skip_ci_allowed?' do
    let(:policy) { build(:scan_execution_policy, skip_ci: skip_ci_config) }

    context 'when skip_ci is not configured' do
      let(:skip_ci_config) { nil }

      it 'returns true for any user' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
      end
    end

    context 'when skip_ci is allowed without allowlist' do
      let(:skip_ci_config) { { allowed: true } }

      it 'returns true for any user' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
      end
    end

    context 'when skip_ci is disallowed without allowlist' do
      let(:skip_ci_config) { { allowed: false } }

      it 'returns false for any user' do
        expect(config.skip_ci_allowed?(123)).to be false
        expect(config.skip_ci_allowed?(456)).to be false
      end
    end

    context 'when skip_ci is allowed with allowlist' do
      let(:skip_ci_config) { { allowed: true, allowlist: { users: [{ id: 123 }, { id: 456 }] } } }

      it 'returns false for allowed users' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
      end

      it 'returns true for non-allowed users' do
        expect(config.skip_ci_allowed?(789)).to be true
      end
    end

    context 'when skip_ci is disallowed with allowlist' do
      let(:skip_ci_config) { { allowed: false, allowlist: { users: [{ id: 123 }, { id: 456 }] } } }

      it 'returns true for allowed users' do
        expect(config.skip_ci_allowed?(123)).to be true
        expect(config.skip_ci_allowed?(456)).to be true
      end

      it 'returns false for non-allowed users' do
        expect(config.skip_ci_allowed?(789)).to be false
      end
    end
  end

  describe '#no_pipeline_allowed?' do
    let(:policy) { build(:scan_execution_policy, no_pipeline: no_pipeline_config) }

    context 'when no_pipeline is not configured' do
      let(:no_pipeline_config) { nil }

      it 'returns true for any user' do
        expect(config.no_pipeline_allowed?(123)).to be true
        expect(config.no_pipeline_allowed?(456)).to be true
      end
    end

    context 'when no_pipeline is allowed without allowlist' do
      let(:no_pipeline_config) { { allowed: true } }

      it 'returns true for any user' do
        expect(config.no_pipeline_allowed?(123)).to be true
        expect(config.no_pipeline_allowed?(456)).to be true
      end
    end

    context 'when no_pipeline is disallowed without allowlist' do
      let(:no_pipeline_config) { { allowed: false } }

      it 'returns false for any user' do
        expect(config.no_pipeline_allowed?(123)).to be false
        expect(config.no_pipeline_allowed?(456)).to be false
      end
    end

    context 'when no_pipeline is allowed with allowlist' do
      let(:no_pipeline_config) { { allowed: true, allowlist: { users: [{ id: 123 }, { id: 456 }] } } }

      it 'returns false for allowed users' do
        expect(config.no_pipeline_allowed?(123)).to be true
        expect(config.no_pipeline_allowed?(456)).to be true
      end

      it 'returns true for non-allowed users' do
        expect(config.no_pipeline_allowed?(789)).to be true
      end
    end

    context 'when no_pipeline is disallowed with allowlist' do
      let(:no_pipeline_config) { { allowed: false, allowlist: { users: [{ id: 123 }, { id: 456 }] } } }

      it 'returns true for allowed users' do
        expect(config.no_pipeline_allowed?(123)).to be true
        expect(config.no_pipeline_allowed?(456)).to be true
      end

      it 'returns false for non-allowed users' do
        expect(config.no_pipeline_allowed?(789)).to be false
      end
    end
  end
end
