# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::Configuration::Defaults::DependencyScanningPostProcessing,
  feature_category: :security_testing_configuration do
  describe 'VALUES' do
    it 'is frozen' do
      expect(described_class::VALUES).to be_frozen
    end

    it 'declares the expected defaults' do
      expect(described_class::VALUES).to eq(
        auto_remediation: {
          cooldown: 7,
          severity_level: 'high',
          upgrade_policy: 'minor',
          open_merge_requests_limit: 10,
          runner_tags: []
        }
      )
    end
  end
end
