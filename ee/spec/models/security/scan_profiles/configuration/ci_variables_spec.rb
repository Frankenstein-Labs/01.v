# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanProfiles::Configuration::CiVariables, feature_category: :security_testing_configuration do
  describe '.build' do
    let(:mappings) do
      {
        test_scan: {
          bool_key: { env: 'TEST_BOOL', type: :boolean },
          string_key: { env: 'TEST_STRING', type: :string },
          array_key: { env: 'TEST_ARRAY', type: :comma_separated_strings }
        }
      }
    end

    before do
      stub_const("#{described_class}::MAPPINGS", mappings)
    end

    it 'serializes each declared type', :aggregate_failures do
      config = { bool_key: true, string_key: 42, array_key: %w[a b c] }

      expect(described_class.build(:test_scan, config)).to eq(
        'TEST_BOOL' => 'true',
        'TEST_STRING' => '42',
        'TEST_ARRAY' => 'a,b,c'
      )
    end

    it 'serializes a false boolean to the string "false"' do
      expect(described_class.build(:test_scan, { bool_key: false })).to eq('TEST_BOOL' => 'false')
    end

    it 'joins a single (non-array) value for the comma_separated_strings type' do
      expect(described_class.build(:test_scan, { array_key: 'solo' })).to eq('TEST_ARRAY' => 'solo')
    end

    it 'resolves both symbol and string config keys', :aggregate_failures do
      expect(described_class.build(:test_scan, { string_key: 'from_symbol' })).to eq('TEST_STRING' => 'from_symbol')
      expect(described_class.build(:test_scan, { 'string_key' => 'from_string' })).to eq('TEST_STRING' => 'from_string')
    end

    it 'returns an empty hash for an unknown scan type' do
      expect(described_class.build(:unknown_scan, { string_key: 'x' })).to eq({})
    end

    it 'returns an empty hash for a nil scan type' do
      expect(described_class.build(nil, { string_key: 'x' })).to eq({})
    end

    it 'returns an empty hash for a nil config' do
      expect(described_class.build(:test_scan, nil)).to eq({})
    end

    it 'returns an empty hash for a nil value in a config' do
      expect(described_class.build(:test_scan, { bool_key: nil })).to eq({})
    end
  end

  describe 'secret_detection mapping' do
    it 'maps each configured value to its environment variable', :aggregate_failures do
      config = {
        secure_analyzers_prefix: 'registry.example.com',
        image_suffix: '-fips',
        historic_scan: true,
        log_options: 'abc..def',
        excluded_paths: %w[spec tmp],
        ruleset_git_reference: 'refs/heads/main'
      }

      expect(described_class.build(:secret_detection, config)).to eq(
        'SECURE_ANALYZERS_PREFIX' => 'registry.example.com',
        'SECRET_DETECTION_IMAGE_SUFFIX' => '-fips',
        'SECRET_DETECTION_HISTORIC_SCAN' => 'true',
        'SECRET_DETECTION_LOG_OPTIONS' => 'abc..def',
        'SECRET_DETECTION_EXCLUDED_PATHS' => 'spec,tmp',
        'SECRET_DETECTION_RULESET_GIT_REFERENCE' => 'refs/heads/main'
      )
    end
  end
end
