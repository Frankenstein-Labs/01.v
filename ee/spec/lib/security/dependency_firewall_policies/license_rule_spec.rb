# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::DependencyFirewallPolicies::LicenseRule, feature_category: :dependency_firewall do
  let(:denied_rule) do
    {
      type: "license",
      denied: [{ name: 'MIT' }, { name: 'GPL-3.0' }],
      allowed: [],
      exceptions: [{ purl: 'pkg:npm/lodash@4.17.21' }]
    }
  end

  let(:allowed_rule) do
    {
      type: "license",
      denied: [],
      allowed: [{ name: 'MIT' }, { name: 'Apache-2.0' }],
      exceptions: []
    }
  end

  let(:vulnerability_rule) do
    {
      type: "vulnerability",
      denied: [{ name: 'CVE-2023-1234' }],
      allowed: [],
      exceptions: []
    }
  end

  describe '#denied_names' do
    it 'returns the names of the denied licenses' do
      expect(described_class.new(denied_rule).denied_names).to match_array(['MIT', 'GPL-3.0'])
    end

    it 'returns an empty array when there are no denied licenses' do
      expect(described_class.new(allowed_rule).denied_names).to eq([])
    end
  end

  describe '#evaluate' do
    let(:package) { { name: 'express', purl_type: 'npm', version: '4.18.0' } }
    let(:licenses) { [] }

    subject { described_class.new(rule).evaluate(package, metadata: { licenses: licenses }) }

    context 'when rule is not a license rule' do
      let(:rule) { vulnerability_rule }
      let(:licenses) { ['MIT'] }

      it { is_expected.to be_nil }
    end

    context 'with denied rule' do
      let(:rule) { denied_rule }

      context 'when license is in denied list' do
        let(:licenses) { ['MIT'] }

        it { is_expected.to eq({ action: :denied, reason: :evaluation }) }
      end

      context 'when any license is denied' do
        let(:licenses) { %w[MIT Apache-2.0] }

        it { is_expected.to eq({ action: :denied, reason: :evaluation }) }
      end

      context 'when license is not in denied list' do
        let(:licenses) { ['Apache-2.0'] }

        it { is_expected.to eq({ action: :allowed, reason: :evaluation }) }
      end

      context 'when multiple licenses and none are denied' do
        let(:licenses) { %w[Apache-2.0 BSD-3-Clause] }

        it { is_expected.to eq({ action: :allowed, reason: :evaluation }) }
      end
    end

    context 'with allowed rule' do
      let(:rule) { allowed_rule }

      context 'when all licenses are in allowed list' do
        let(:licenses) { ['MIT'] }

        it { is_expected.to eq({ action: :allowed, reason: :evaluation }) }
      end

      context 'when all licenses are allowed' do
        let(:licenses) { %w[MIT Apache-2.0] }

        it { is_expected.to eq({ action: :allowed, reason: :evaluation }) }
      end

      context 'when some licenses are not in allowed list' do
        let(:licenses) { ['GPL-3.0'] }

        it { is_expected.to eq({ action: :denied, reason: :evaluation }) }
      end

      context 'when any license is not allowed' do
        let(:licenses) { %w[MIT GPL-3.0] }

        it { is_expected.to eq({ action: :denied, reason: :evaluation }) }
      end
    end

    context 'with empty licenses array' do
      let(:licenses) { [] }

      context 'for denied rule' do
        let(:rule) { denied_rule }

        it 'allows because a license rule cannot match without license data' do
          is_expected.to eq({ action: :allowed, reason: :evaluation })
        end
      end

      context 'for allowed rule' do
        let(:rule) { allowed_rule }

        it 'allows because a license rule cannot match without license data' do
          is_expected.to eq({ action: :allowed, reason: :evaluation })
        end
      end
    end
  end
end
