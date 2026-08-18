# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe Security::DependencyFirewallPolicies::Rule, feature_category: :dependency_firewall do
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

  let(:malicious_rule) do
    {
      type: "malicious",
      denied: [{ is_malicious: true }],
      exceptions: []
    }
  end

  describe '.by_type' do
    it 'returns a LicenseRule for the license type' do
      expect(described_class.by_type(denied_rule))
        .to be_an_instance_of(Security::DependencyFirewallPolicies::LicenseRule)
    end

    it 'returns a VulnerabilityRule for the vulnerability type' do
      expect(described_class.by_type(vulnerability_rule))
        .to be_an_instance_of(Security::DependencyFirewallPolicies::VulnerabilityRule)
    end

    it 'returns a MaliciousRule for the malicious type' do
      expect(described_class.by_type(malicious_rule))
        .to be_an_instance_of(Security::DependencyFirewallPolicies::MaliciousRule)
    end

    it 'returns a base Rule for an unknown type' do
      expect(described_class.by_type({ type: "unknown" }))
        .to be_an_instance_of(described_class)
    end
  end

  describe '#to_h' do
    it 'returns the underlying rule hash' do
      expect(described_class.new(denied_rule).to_h).to eq(denied_rule)
    end

    it 'returns an empty hash when initialized with nil' do
      expect(described_class.new(nil).to_h).to eq({})
    end

    it 'excludes the internal rule_id so it does not leak into serialized content' do
      rule = described_class.new(denied_rule.merge(rule_id: 42))

      expect(rule.to_h).not_to have_key(:rule_id)
      expect(rule.to_h).to eq(denied_rule)
    end
  end

  describe '#rule_id' do
    it 'returns the threaded rule_id' do
      expect(described_class.new(denied_rule.merge(rule_id: 42)).rule_id).to eq(42)
    end

    it 'returns nil when no rule_id was threaded in' do
      expect(described_class.new(denied_rule).rule_id).to be_nil
    end
  end

  describe '#license_rule?' do
    context 'when type is license' do
      subject { described_class.new(denied_rule).license_rule? }

      it { is_expected.to be true }
    end

    context 'when type is not license' do
      subject { described_class.new(vulnerability_rule).license_rule? }

      it { is_expected.to be false }
    end
  end

  describe '#malicious_rule?' do
    context 'when type is malicious' do
      subject { described_class.new(malicious_rule).malicious_rule? }

      it { is_expected.to be true }
    end

    context 'when type is not malicious' do
      subject { described_class.new(denied_rule).malicious_rule? }

      it { is_expected.to be false }
    end
  end

  describe '#purl_excepted?' do
    let(:rule) { described_class.new(denied_rule) }

    it 'returns true when package matches an exception purl' do
      expect(rule.purl_excepted?({ name: 'lodash', purl_type: 'npm', version: '4.17.21' })).to be true
    end

    it 'returns false when package does not match any exception purl' do
      expect(rule.purl_excepted?({ name: 'express', purl_type: 'npm', version: '4.18.0' })).to be false
    end

    it 'returns false when version is nil and does not match with package version' do
      expect(rule.purl_excepted?({ name: 'express', purl_type: 'npm' })).to be false
    end

    context 'when version is blank' do
      let(:denied_rule_no_version) do
        {
          type: "license",
          denied: [{ name: 'MIT' }],
          allowed: [],
          exceptions: [{ purl: 'pkg:npm/lodash' }]
        }
      end

      let(:rule) { described_class.new(denied_rule_no_version) }

      it 'matches exception purl without version' do
        expect(rule.purl_excepted?({ name: 'lodash', purl_type: 'npm', version: nil })).to be true
      end

      it 'matches exception purl when version is empty string' do
        expect(rule.purl_excepted?({ name: 'lodash', purl_type: 'npm', version: '' })).to be true
      end

      it 'matches when version is present but exception has none' do
        expect(rule.purl_excepted?({ name: 'lodash', purl_type: 'npm', version: '4.17.21' })).to be true
      end
    end

    context 'when exception purl is a scoped package without version' do
      let(:scoped_rule) do
        {
          type: "license",
          denied: [{ name: 'MIT' }],
          allowed: [],
          exceptions: [{ purl: 'pkg:npm/@babel/core' }]
        }
      end

      let(:rule) { described_class.new(scoped_rule) }

      it 'matches any version of the scoped package' do
        expect(rule.purl_excepted?({ name: '@babel/core', purl_type: 'npm', version: '7.0.0' })).to be true
      end
    end
  end

  describe '#evaluate' do
    let(:package) { { name: 'express', purl_type: 'npm', version: '4.18.0' } }
    let(:licenses) { [] }

    subject { described_class.new(rule).evaluate(package, metadata: { licenses: licenses }) }

    context 'when package is in exceptions' do
      let(:rule) { denied_rule }
      let(:package) { { name: 'lodash', purl_type: 'npm', version: '4.17.21' } }
      let(:licenses) { ['MIT'] }

      it { is_expected.to eq({ action: :allowed, reason: :exception }) }
    end
  end
end
