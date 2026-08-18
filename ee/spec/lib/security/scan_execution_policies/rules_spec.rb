# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::Rules, feature_category: :security_policy_management do
  describe '#initialize' do
    let(:rules_data) do
      [
        { type: 'pipeline', branches: ['main'] },
        { type: 'schedule', cadence: '0 22 * * 1-5' },
        { type: 'pipeline', branch_type: 'protected' }
      ]
    end

    it 'converts rules data to Rule objects' do
      rules = described_class.new(rules_data)

      expect(rules.rules.length).to eq(3)
      expect(rules.rules).to all(be_a(Security::ScanExecutionPolicies::Rule))
      expect(rules.rules.map(&:type)).to match_array(%w[pipeline schedule pipeline])
    end

    context 'when rules is nil' do
      it 'returns an empty array' do
        rules = described_class.new(nil)
        expect(rules.rules).to be_empty
      end
    end
  end
end
