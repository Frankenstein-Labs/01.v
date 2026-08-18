# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicyRule, feature_category: :security_policy_management do
  it_behaves_like 'policy rule' do
    let(:rule_hash) { build(:scan_execution_policy)[:rules].first }
    let(:policy_type) { :scan_execution_policy }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:security_policy) }
  end

  describe 'validations' do
    describe 'content' do
      subject(:rule) { build(:scan_execution_policy_rule, trait) }

      context 'when pipeline' do
        let(:trait) { :pipeline }

        it { is_expected.to be_valid }
      end

      context 'when schedule' do
        let(:trait) { :schedule }

        it { is_expected.to be_valid }
      end
    end
  end

  describe '.undeleted' do
    let_it_be(:rule_with_positive_index) { create(:scan_execution_policy_rule, rule_index: 1) }
    let_it_be(:rule_with_zero_index) { create(:scan_execution_policy_rule, rule_index: 0) }
    let_it_be(:rule_with_negative_index) { create(:scan_execution_policy_rule, rule_index: -1) }

    it 'returns rules with rule_index greater than or equal to 0' do
      result = described_class.undeleted

      expect(result).to contain_exactly(rule_with_positive_index, rule_with_zero_index)
      expect(result).not_to include(rule_with_negative_index)
    end
  end
end
