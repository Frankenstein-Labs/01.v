# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanExecutionPolicies::Action, feature_category: :security_policy_management do
  describe '#scan' do
    it 'returns the scan type' do
      action = described_class.new({ scan: 'sast' })
      expect(action.scan).to eq('sast')
    end

    context 'with valid scan types from schema' do
      %w[dast secret_detection container_scanning cluster_image_scanning sast dependency_scanning
        sast_iac].each do |scan_type|
        it "returns #{scan_type}" do
          action = described_class.new({ scan: scan_type })
          expect(action.scan).to eq(scan_type)
        end
      end
    end
  end

  describe '#scanner_profile' do
    context 'when scanner_profile is present' do
      it 'returns the scanner_profile value' do
        action = described_class.new({ scan: 'dast', scanner_profile: 'my-scanner-profile' })
        expect(action.scanner_profile).to eq('my-scanner-profile')
      end
    end

    context 'when scanner_profile is not present' do
      it 'returns nil' do
        action = described_class.new({ scan: 'sast' })
        expect(action.scanner_profile).to be_nil
      end
    end
  end

  describe '#site_profile' do
    context 'when site_profile is present' do
      it 'returns the site_profile value' do
        action = described_class.new({ scan: 'dast', site_profile: 'my-site-profile' })
        expect(action.site_profile).to eq('my-site-profile')
      end
    end

    context 'when site_profile is null' do
      it 'returns nil' do
        action = described_class.new({ scan: 'dast', site_profile: nil })
        expect(action.site_profile).to be_nil
      end
    end

    context 'when site_profile is not present' do
      it 'returns nil' do
        action = described_class.new({ scan: 'sast' })
        expect(action.site_profile).to be_nil
      end
    end
  end

  describe '#variables' do
    context 'when variables is present' do
      it 'returns the variables hash' do
        variables = { 'SECURE_ANALYZERS_PREFIX' => 'registry.example.com', 'CI_DEBUG_TRACE' => 'true' }
        action = described_class.new({ scan: 'sast', variables: variables })
        expect(action.variables).to eq(variables)
      end

      it 'handles variables matching patternProperties schema' do
        variables = { 'VAR_NAME' => 'value', 'ANOTHER_VAR_123' => 'another_value' }
        action = described_class.new({ scan: 'sast', variables: variables })
        expect(action.variables).to eq(variables)
      end
    end

    context 'when variables is not present' do
      it 'returns an empty hash' do
        action = described_class.new({ scan: 'sast' })
        expect(action.variables).to eq({})
      end
    end
  end

  describe '#tags' do
    context 'when tags is present' do
      it 'returns the tags array' do
        action = described_class.new({ scan: 'sast', tags: %w[docker linux] })
        expect(action.tags).to match_array(%w[docker linux])
      end

      it 'handles single tag' do
        action = described_class.new({ scan: 'sast', tags: ['docker'] })
        expect(action.tags).to match_array(['docker'])
      end
    end

    context 'when tags is not present' do
      it 'returns an empty array' do
        action = described_class.new({ scan: 'sast' })
        expect(action.tags).to be_empty
      end
    end
  end

  describe '#template' do
    context 'when template is present' do
      it 'returns default template' do
        action = described_class.new({ scan: 'sast', template: 'default' })
        expect(action.template).to eq('default')
      end

      it 'returns latest template' do
        action = described_class.new({ scan: 'sast', template: 'latest' })
        expect(action.template).to eq('latest')
      end

      it 'returns versioned template for dependency_scanning' do
        action = described_class.new({ scan: 'dependency_scanning', template: 'v2' })
        expect(action.template).to eq('v2')
      end
    end

    context 'when template is not present' do
      it 'returns nil' do
        action = described_class.new({ scan: 'sast' })
        expect(action.template).to be_nil
      end
    end
  end

  describe '#scan_settings' do
    context 'when scan_settings is present' do
      it 'returns a ScanSettings instance' do
        scan_settings_data = { ignore_default_before_after_script: true }
        action = described_class.new({ scan: 'sast', scan_settings: scan_settings_data })
        expect(action.scan_settings).to be_a(Security::ScanExecutionPolicies::ScanSettings)
      end

      it 'passes scan_settings data to ScanSettings' do
        scan_settings_data = { ignore_default_before_after_script: false }
        expect(Security::ScanExecutionPolicies::ScanSettings).to receive(:new).with(scan_settings_data)
        action = described_class.new({ scan: 'sast', scan_settings: scan_settings_data })
        action.scan_settings
      end
    end

    context 'when scan_settings is not present' do
      it 'returns a ScanSettings instance with empty hash' do
        action = described_class.new({ scan: 'sast' })
        expect(action.scan_settings).to be_a(Security::ScanExecutionPolicies::ScanSettings)
      end

      it 'passes empty hash to ScanSettings' do
        expect(Security::ScanExecutionPolicies::ScanSettings).to receive(:new).with({})
        action = described_class.new({ scan: 'sast' })
        action.scan_settings
      end
    end
  end

  describe 'DAST scan with required fields' do
    it 'handles complete DAST action with all fields' do
      action_data = {
        scan: 'dast',
        site_profile: 'production-site',
        scanner_profile: 'production-scanner',
        variables: { 'DAST_WEBSITE' => 'https://example.com' },
        tags: ['dast'],
        template: 'latest',
        scan_settings: { ignore_default_before_after_script: true }
      }
      action = described_class.new(action_data)

      expect(action.scan).to eq('dast')
      expect(action.site_profile).to eq('production-site')
      expect(action.scanner_profile).to eq('production-scanner')
      expect(action.variables).to eq({ 'DAST_WEBSITE' => 'https://example.com' })
      expect(action.tags).to match_array(['dast'])
      expect(action.template).to eq('latest')
      expect(action.scan_settings.ignore_default_before_after_script).to be true
    end
  end

  describe 'non-DAST scan with limited fields' do
    it 'handles secret_detection action' do
      action_data = {
        scan: 'secret_detection',
        variables: { 'SECURE_ANALYZERS_PREFIX' => 'registry.example.com' },
        tags: ['docker'],
        template: 'default'
      }
      action = described_class.new(action_data)

      expect(action.scan).to eq('secret_detection')
      expect(action.variables).to eq({ 'SECURE_ANALYZERS_PREFIX' => 'registry.example.com' })
      expect(action.tags).to match_array(['docker'])
      expect(action.template).to eq('default')
    end
  end
end
