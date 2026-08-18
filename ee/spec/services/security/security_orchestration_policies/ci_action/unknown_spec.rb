# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::SecurityOrchestrationPolicies::CiAction::Unknown,
  feature_category: :security_policy_management do
  describe '#config' do
    subject { described_class.new(action, anything, anything, 0).config }

    let(:action) { { scan: 'unknown' } }

    let(:expected_ci_config) do
      {
        'unknown-0': {
          'script' => 'echo "Error during Scan execution: Invalid Scan type" && false',
          'allow_failure' => true
        }
      }
    end

    it { is_expected.to eq(expected_ci_config) }
  end
end
