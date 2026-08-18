# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::ScanSettings, feature_category: :security_policy_management do
  describe '#ignore_default_before_after_script' do
    context 'when ignore_default_before_after_script is true' do
      it 'returns true' do
        scan_settings = described_class.new({ ignore_default_before_after_script: true })
        expect(scan_settings.ignore_default_before_after_script).to be true
      end
    end

    context 'when ignore_default_before_after_script is false' do
      it 'returns false' do
        scan_settings = described_class.new({ ignore_default_before_after_script: false })
        expect(scan_settings.ignore_default_before_after_script).to be false
      end
    end

    context 'when ignore_default_before_after_script is not present' do
      it 'returns nil' do
        scan_settings = described_class.new({})
        expect(scan_settings.ignore_default_before_after_script).to be_nil
      end
    end
  end

  describe 'when scan_settings is nil' do
    it 'handles nil gracefully' do
      scan_settings = described_class.new(nil)
      expect(scan_settings.ignore_default_before_after_script).to be_nil
    end
  end
end
