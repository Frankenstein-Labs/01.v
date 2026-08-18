# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ExecutionPolicy::VariablesOverride, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }
  let(:variables_override) { described_class.new(project: project, job_options: job_options) }

  describe '#replaces_legacy_scan_execution_policy_variables_builder?' do
    subject { variables_override.replaces_legacy_scan_execution_policy_variables_builder? }

    context 'when job_options is nil' do
      let(:job_options) { nil }

      it { is_expected.to be false }
    end

    context 'without policy option' do
      let(:job_options) { {} }

      it { is_expected.to be false }
    end

    context 'with policy option but no variables_override (FF disabled scenario)' do
      let(:job_options) { { policy: { name: 'Policy' } } }

      it { is_expected.to be false }
    end

    context 'with policy option and variables_override (SEP)' do
      let(:job_options) { { policy: { name: 'Policy', variables_override: { allowed: true } } } }

      it { is_expected.to be true }
    end

    context 'with PEP job and variables_override' do
      let(:job_options) do
        { policy: { name: 'Policy', pipeline_execution_policy_job: true, variables_override: { allowed: false } } }
      end

      it { is_expected.to be false }
    end
  end

  describe '#apply_highest_precedence' do
    subject { variables_override.apply_highest_precedence(variables, yaml_variables).to_runner_variables }

    let(:variables) do
      Gitlab::Ci::Variables::Collection.new([
        { key: 'SAST_DISABLED', value: 'true' },
        { key: 'SECRET_DETECTION_DISABLED', value: 'true' }
      ])
    end

    let(:yaml_variables) do
      Gitlab::Ci::Variables::Collection.new([{ key: 'SAST_DISABLED', value: 'false' }])
    end

    let(:expected_original_variables) do
      [
        { key: 'SAST_DISABLED', value: 'true', public: true, masked: false },
        { key: 'SECRET_DETECTION_DISABLED', value: 'true', public: true, masked: false }
      ]
    end

    context 'when job_options is nil' do
      let(:job_options) { nil }

      it { is_expected.to eq expected_original_variables }
    end

    context 'without `policy` option' do
      let(:job_options) { {} }

      it { is_expected.to eq expected_original_variables }
    end

    context 'with other options' do
      let(:job_options) { { another_option: true } }

      it { is_expected.to eq expected_original_variables }
    end

    context 'with `policy` option' do
      let(:job_options) { { policy: { name: 'Policy' } } }
      let(:expected_enforced_variables) do
        [
          { key: 'SECRET_DETECTION_DISABLED', value: 'true', public: true, masked: false },
          { key: 'SAST_DISABLED', value: 'false', public: true, masked: false }
        ]
      end

      it { is_expected.to eq expected_original_variables }

      context 'for pipeline execution policy job' do
        context 'with options in the new format' do
          let(:job_options) { { policy: { name: 'Policy', pipeline_execution_policy_job: true } } }

          it { is_expected.to eq expected_enforced_variables }
        end

        # TODO: Remove with https://gitlab.com/gitlab-org/gitlab/-/issues/577272
        context 'with options in the old format' do
          let(:job_options) { { execution_policy_job: true } }

          it { is_expected.to eq expected_enforced_variables }
        end

        context 'with `variables_override` option' do
          let(:job_options) do
            { policy: { pipeline_execution_policy_job: true, name: 'Policy', variables_override: { allowed: false } } }
          end

          it { is_expected.to eq expected_original_variables }
        end
      end

      # SEP variable precedence is handled by Variables::Builder::ScanExecutionPolicies
      context 'for scan execution policy job' do
        let(:job_options) { { policy: { name: 'Policy' } } }

        it { is_expected.to eq expected_original_variables }
      end
    end
  end

  describe '#apply_variables_override' do
    subject { variables_override.apply_variables_override(variables, source: source).to_hash }

    let(:variables) { ::Gitlab::Ci::Variables::Collection.new([{ key: 'SAST_DISABLED', value: 'true' }]) }
    let(:source) { nil }

    context 'when job_options is nil' do
      let(:job_options) { nil }

      it { is_expected.to eq('SAST_DISABLED' => 'true') }
    end

    context 'without `policy` option' do
      let(:job_options) { {} }

      it { is_expected.to eq('SAST_DISABLED' => 'true') }
    end

    shared_examples_for 'variables override' do
      context 'when `variables_override` is allowed' do
        context 'without `exceptions`' do
          let(:override_option) { { allowed: true } }

          it { is_expected.to eq('SAST_DISABLED' => 'true') }
        end

        context 'with `exceptions`' do
          let(:override_option) { { allowed: true, exceptions: %w[SAST_DISABLED] } }

          context 'when matching' do
            it { is_expected.to eq({}) }
          end

          context 'when not matching' do
            let(:override_option) { { allowed: true, exceptions: %w[DAST_DISABLED] } }

            it { is_expected.to eq('SAST_DISABLED' => 'true') }
          end
        end
      end

      context 'when `variables_override` is disallowed' do
        context 'without `exceptions`' do
          let(:override_option) { { allowed: false } }

          it { is_expected.to eq({}) }
        end

        context 'with `exceptions`' do
          let(:override_option) { { allowed: false, exceptions: %w[SAST_DISABLED] } }

          context 'when matching' do
            it { is_expected.to eq('SAST_DISABLED' => 'true') }
          end

          context 'when not matching' do
            let(:override_option) { { allowed: false, exceptions: %w[DAST_DISABLED] } }

            it { is_expected.to eq({}) }
          end
        end
      end
    end

    context 'for scan execution policy job' do
      let(:job_options) { { policy: { name: 'Policy' } } }

      context 'without `variables_override` option' do
        it { is_expected.to eq('SAST_DISABLED' => 'true') }
      end

      context 'with `variables_override` option' do
        let(:job_options) do
          { policy: { name: 'Policy', variables_override: override_option } }
        end

        it_behaves_like 'variables override'
      end
    end

    context 'for pipeline execution policy job' do
      context 'without `variables_override` option' do
        let(:job_options) { { policy: { pipeline_execution_policy_job: true, name: 'Policy' } } }

        it { is_expected.to eq('SAST_DISABLED' => 'true') }
      end

      context 'with `variables_override` option' do
        let(:job_options) do
          { policy: { pipeline_execution_policy_job: true, name: 'Policy', variables_override: override_option } }
        end

        it_behaves_like 'variables override'

        context 'with options in the old format' do
          let(:job_options) do
            { execution_policy_job: true, execution_policy_variables_override: override_option }
          end

          it_behaves_like 'variables override'
        end

        context 'with source: :dotenv' do
          let(:source) { :dotenv }

          context 'when dotenv option is not specified' do
            let(:override_option) { { allowed: false, exceptions: [] } }

            it 'applies policy rules (secure by default)' do
              is_expected.to eq({})
            end
          end

          context 'when dotenv: respect_policy is set' do
            context 'when variables_override is disallowed' do
              let(:override_option) { { allowed: false, exceptions: [], dotenv: 'respect_policy' } }

              it 'applies policy rules to dotenv variables' do
                is_expected.to eq({})
              end

              context 'with matching exceptions' do
                let(:override_option) do
                  { allowed: false, exceptions: %w[SAST_DISABLED], dotenv: 'respect_policy' }
                end

                it { is_expected.to eq('SAST_DISABLED' => 'true') }
              end
            end

            context 'when variables_override is allowed' do
              let(:override_option) { { allowed: true, exceptions: %w[SAST_DISABLED], dotenv: 'respect_policy' } }

              it 'applies denylist to dotenv variables' do
                is_expected.to eq({})
              end
            end
          end

          context 'when dotenv: allow_override is set' do
            let(:override_option) { { allowed: false, exceptions: [], dotenv: 'allow_override' } }

            it 'bypasses policy rules' do
              is_expected.to eq('SAST_DISABLED' => 'true')
            end
          end
        end
      end
    end
  end
end
