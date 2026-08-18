# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::PolicyTuning, feature_category: :security_policy_management do
  describe '#security_report_time_window' do
    it 'returns the security_report_time_window value' do
      policy_tuning = described_class.new({ security_report_time_window: 14 })
      expect(policy_tuning.security_report_time_window).to eq(14)
    end

    context 'when not set' do
      it 'returns nil' do
        policy_tuning = described_class.new({})
        expect(policy_tuning.security_report_time_window).to be_nil
      end
    end
  end

  describe '#unblock_rules_using_execution_policies' do
    it 'returns the unblock_rules_using_execution_policies value' do
      policy_tuning = described_class.new({ unblock_rules_using_execution_policies: true })
      expect(policy_tuning.unblock_rules_using_execution_policies).to be true
    end

    it 'returns false when set to false' do
      policy_tuning = described_class.new({ unblock_rules_using_execution_policies: false })
      expect(policy_tuning.unblock_rules_using_execution_policies).to be false
    end

    context 'when not set' do
      it 'returns nil' do
        policy_tuning = described_class.new({})
        expect(policy_tuning.unblock_rules_using_execution_policies).to be_nil
      end
    end
  end
end
