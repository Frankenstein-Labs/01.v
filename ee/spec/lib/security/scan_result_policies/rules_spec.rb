# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::Rules, feature_category: :security_policy_management do
  describe '#initialize' do
    let(:rules_data) do
      [
        { type: 'scan_finding', branches: ['main'] },
        { type: 'license_scanning', scanners: ['dependency_scanning'] }
      ]
    end

    it 'converts rules data to Rule objects' do
      rules = described_class.new(rules_data)

      expect(rules.rules.length).to eq(2)
      expect(rules.rules).to all(be_a(Security::ScanResultPolicies::Rule))
      expect(rules.rules.map(&:type)).to match_array(%w[scan_finding license_scanning])
    end
  end
end
