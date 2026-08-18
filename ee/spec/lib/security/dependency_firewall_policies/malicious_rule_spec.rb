# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::DependencyFirewallPolicies::MaliciousRule, feature_category: :dependency_firewall do
  let(:malicious_rule) do
    {
      type: "malicious",
      denied: [{ is_malicious: true }],
      exceptions: [{ purl: 'pkg:npm/lodash@4.17.21' }]
    }
  end

  let(:license_rule) do
    {
      type: "license",
      denied: [{ name: 'MIT' }],
      allowed: [],
      exceptions: []
    }
  end

  describe '#evaluate' do
    let(:package) { { name: 'express', purl_type: 'npm', version: '4.18.0' } }
    let(:malicious_packages) { [] }

    subject { described_class.new(rule).evaluate(package, metadata: { malicious_packages: malicious_packages }) }

    context 'when rule is not a malicious rule' do
      let(:rule) { license_rule }
      let(:malicious_packages) { [{ name: 'express' }] }

      it { is_expected.to be_nil }
    end

    context 'with malicious rule' do
      let(:rule) { malicious_rule }

      context 'when the package is flagged as malicious' do
        let(:malicious_packages) { [{ name: 'express' }] }

        it { is_expected.to eq({ action: :denied, reason: :evaluation }) }
      end

      context 'when there is no malicious data for the package' do
        let(:malicious_packages) { [] }

        it { is_expected.to eq({ action: :allowed, reason: :evaluation }) }
      end

      context 'when the package is flagged but matches an exception purl' do
        let(:package) { { name: 'lodash', purl_type: 'npm', version: '4.17.21' } }
        let(:malicious_packages) { [{ name: 'lodash' }] }

        it { is_expected.to eq({ action: :allowed, reason: :exception }) }
      end

      context 'when the rule denies without is_malicious set' do
        let(:rule) { malicious_rule.merge(denied: [{ is_malicious: false }]) }
        let(:malicious_packages) { [{ name: 'express' }] }

        it { is_expected.to eq({ action: :allowed, reason: :evaluation }) }
      end
    end
  end
end
