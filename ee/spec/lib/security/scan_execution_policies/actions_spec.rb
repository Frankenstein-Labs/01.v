# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::Actions, feature_category: :security_policy_management do
  describe '#initialize' do
    let(:actions_data) do
      [
        { scan: 'sast', template: 'default' },
        { scan: 'dast', site_profile: 'production-site', scanner_profile: 'production-scanner' },
        { scan: 'secret_detection', tags: ['docker'], variables: { 'VAR' => 'value' } }
      ]
    end

    it 'converts actions data to Action objects' do
      actions = described_class.new(actions_data)

      expect(actions.actions.length).to eq(3)
      expect(actions.actions).to all(be_a(Security::ScanExecutionPolicies::Action))
      expect(actions.actions.map(&:scan)).to match_array(%w[sast dast secret_detection])
    end

    context 'when actions is nil' do
      it 'returns an empty array' do
        actions = described_class.new(nil)
        expect(actions.actions).to be_empty
      end
    end
  end
end
