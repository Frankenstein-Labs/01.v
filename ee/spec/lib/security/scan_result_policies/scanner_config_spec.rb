# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::ScanResultPolicies::ScannerConfig, feature_category: :security_policy_management do
  describe '#to_h' do
    context 'when all attributes are present' do
      it 'returns a hash with all attributes' do
        config = described_class.new(
          type: 'sast',
          vulnerability_attributes: { fix_available: true },
          severity_levels: %w[critical high],
          vulnerabilities_allowed: 5,
          vulnerability_states: %w[detected confirmed]
        )

        expect(config.to_h).to eq({
          type: 'sast',
          vulnerability_attributes: { fix_available: true },
          severity_levels: %w[critical high],
          vulnerabilities_allowed: 5,
          vulnerability_states: %w[detected confirmed]
        })
      end
    end

    context 'when only required attributes are present' do
      it 'returns a hash with type and vulnerability_attributes' do
        config = described_class.new(type: 'sast')

        expect(config.to_h).to eq({
          type: 'sast',
          vulnerability_attributes: nil
        })
      end
    end

    context 'when some optional attributes are present' do
      it 'includes only non-nil optional attributes' do
        config = described_class.new(
          type: 'dependency_scanning',
          vulnerability_attributes: { known_exploited: true },
          severity_levels: %w[medium]
        )

        expect(config.to_h).to eq({
          type: 'dependency_scanning',
          vulnerability_attributes: { known_exploited: true },
          severity_levels: %w[medium]
        })
      end
    end

    context 'when is_malicious is true' do
      it 'includes is_malicious' do
        config = described_class.new(type: 'dependency_scanning', is_malicious: true)

        expect(config.to_h).to eq({
          type: 'dependency_scanning',
          vulnerability_attributes: nil,
          is_malicious: true
        })
      end
    end

    context 'when is_malicious is false' do
      it 'omits is_malicious' do
        config = described_class.new(type: 'dependency_scanning', is_malicious: false)

        expect(config.to_h).not_to have_key(:is_malicious)
      end
    end
  end

  describe '#is_malicious' do
    it 'defaults to false' do
      expect(described_class.new(type: 'sast').is_malicious).to be false
    end

    it 'returns the provided value' do
      expect(described_class.new(type: 'sast', is_malicious: true).is_malicious).to be true
    end
  end
end
