# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::DeprecatedPropertiesChecker, feature_category: :security_policy_management do
  let_it_be(:deprecated_properties_checker) do
    Class.new do
      include Security::SecurityOrchestrationPolicies::DeprecatedPropertiesChecker
    end.new
  end

  describe '#deprecated_properties' do
    subject { deprecated_properties_checker.deprecated_properties(policy) }

    context 'when the policy is a approval_policy' do
      let(:policy) { build(:approval_policy, rules: rules) }

      context 'when the policy has no rules' do
        let(:rules) { nil }

        it { is_expected.to be_empty }
      end

      context 'when the policy has rules' do
        let(:rules) { [rule] }

        context 'when the policy does not contains deprecated properties' do
          let(:rule) do
            {
              type: 'license_finding',
              branches: %w[master],
              match_on_inclusion_license: true,
              license_types: %w[BSD MIT],
              license_states: %w[detected]
            }
          end

          it { is_expected.to be_empty }
        end

        context 'when the policy contains deprecated properties' do
          let(:rule) do
            {
              type: 'license_finding',
              branches: %w[master],
              match_on_inclusion: true,
              license_types: %w[BSD MIT],
              license_states: %w[newly_detected]
            }
          end

          let(:rule_2) do
            {
              type: 'scan_finding',
              branches: [],
              scanners: %w[container_scanning],
              vulnerabilities_allowed: 0,
              severity_levels: %w[critical],
              vulnerability_states: %w[newly_detected]
            }
          end

          context 'when the policy contains multiple deprecated properties' do
            let(:rules) { [rule, rule_2] }

            it { is_expected.to match_array(%w[match_on_inclusion newly_detected]) }
          end

          context 'when the policy contains the match_on_inclusion property' do
            let(:rule) do
              {
                type: 'license_finding',
                branches: %w[master],
                match_on_inclusion: true,
                license_types: %w[BSD MIT],
                license_states: %w[detected]
              }
            end

            it { is_expected.to match_array(['match_on_inclusion']) }
          end

          context 'when the policy contains the vulnerability_state newly_detected' do
            let(:rules) { [rule_2] }

            it { is_expected.to match_array(['newly_detected']) }
          end
        end
      end
    end

    context 'when the policy is a scan_execution_policy' do
      let(:policy) { build(:scan_execution_policy) }

      it { is_expected.to be_empty }
    end
  end
end
