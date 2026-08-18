# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PolicyRule, feature_category: :security_policy_management do
  describe '.for_policy_type' do
    subject(:policy) { described_class.for_policy_type(policy_type) }

    context 'for approval policy' do
      let(:policy_type) { :approval_policy }

      it { is_expected.to be(Security::ApprovalPolicyRule) }
    end

    context 'for scan execution policy' do
      let(:policy_type) { :scan_execution_policy }

      it { is_expected.to be(Security::ScanExecutionPolicyRule) }
    end

    context 'for vulnerability management policy' do
      let(:policy_type) { :vulnerability_management_policy }

      it { is_expected.to be(Security::VulnerabilityManagementPolicyRule) }
    end

    context 'for dependency firewall policy' do
      let(:policy_type) { :dependency_firewall_policy }

      it { is_expected.to be(Security::DependencyFirewallPolicyRule) }
    end

    context 'for unrecognized policy type' do
      let(:policy_type) { :foobar }

      it 'raises' do
        expect { policy }.to raise_error(ArgumentError)
      end
    end
  end
end
