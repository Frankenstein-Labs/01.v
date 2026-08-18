# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::Rule, feature_category: :security_policy_management do
  describe '#type' do
    it 'returns the rule type' do
      rule = described_class.new({ type: 'scan_finding' })
      expect(rule.type).to eq('scan_finding')
    end
  end

  describe '#branches' do
    it 'returns the branches array' do
      rule = described_class.new({ branches: %w[main develop] })
      expect(rule.branches).to match_array(%w[main develop])
    end
  end

  describe '#branch_type' do
    it 'returns the branch_type' do
      rule = described_class.new({ branch_type: 'protected' })
      expect(rule.branch_type).to eq('protected')
    end
  end

  describe '#scanners' do
    it 'returns the scanners array' do
      rule = described_class.new({ scanners: %w[sast dependency_scanning] })
      expect(rule.scanners).to match_array(%w[sast dependency_scanning])
    end
  end

  describe '#vulnerabilities_allowed' do
    it 'returns the vulnerabilities_allowed value' do
      rule = described_class.new({ vulnerabilities_allowed: 5 })
      expect(rule.vulnerabilities_allowed).to eq(5)
    end
  end

  describe '#severity_levels' do
    it 'returns the severity_levels array' do
      rule = described_class.new({ severity_levels: %w[high critical] })
      expect(rule.severity_levels).to match_array(%w[high critical])
    end
  end

  describe '#vulnerability_states' do
    it 'returns the vulnerability_states array' do
      rule = described_class.new({ vulnerability_states: ['newly_detected'] })
      expect(rule.vulnerability_states).to match_array(['newly_detected'])
    end
  end

  describe '#commits' do
    it 'returns the commits array' do
      rule = described_class.new({ commits: %w[abc123 def456] })
      expect(rule.commits).to match_array(%w[abc123 def456])
    end
  end

  describe '#branch_exceptions' do
    context 'when branch_exceptions is present' do
      it 'returns the branch_exceptions array' do
        rule = described_class.new({ branch_exceptions: ['feature/*', 'hotfix/*'] })
        expect(rule.branch_exceptions).to match_array(['feature/*', 'hotfix/*'])
      end
    end

    context 'when branch_exceptions is not present' do
      it 'returns an empty array' do
        rule = described_class.new({})
        expect(rule.branch_exceptions).to be_empty
      end
    end
  end

  describe '#vulnerability_attributes' do
    context 'when vulnerability_attributes is present' do
      it 'returns the vulnerability_attributes hash' do
        rule = described_class.new({ vulnerability_attributes: { cve: 'CVE-2023-1234' } })
        expect(rule.vulnerability_attributes).to eq({ cve: 'CVE-2023-1234' })
      end
    end

    context 'when vulnerability_attributes is not present' do
      it 'returns an empty hash' do
        rule = described_class.new({})
        expect(rule.vulnerability_attributes).to be_empty
      end
    end
  end

  describe '#vulnerability_age' do
    context 'when vulnerability_age has all required keys' do
      it 'returns the normalized hash with symbol operator and interval' do
        rule = described_class.new(
          { vulnerability_age: { operator: 'greater_than', interval: 'day', value: 30 } }
        )
        expect(rule.vulnerability_age).to eq(operator: :greater_than, interval: :day, value: 30)
      end
    end

    context 'when vulnerability_age is missing a required key' do
      it 'returns an empty hash when interval is missing' do
        rule = described_class.new({ vulnerability_age: { operator: 'greater_than', value: 30 } })
        expect(rule.vulnerability_age).to eq({})
      end
    end

    context 'when vulnerability_age is not present' do
      it 'returns an empty hash' do
        rule = described_class.new({})
        expect(rule.vulnerability_age).to be_empty
      end
    end
  end

  describe '#newly_detected?' do
    it { expect(described_class.new({ license_states: %w[newly_detected] }).newly_detected?).to be(true) }
    it { expect(described_class.new({ license_states: %w[detected] }).newly_detected?).to be(false) }
    it { expect(described_class.new({}).newly_detected?).to be(false) }
  end

  describe '#only_newly_detected_licenses?' do
    it 'is true for only newly_detected' do
      expect(described_class.new({ license_states: %w[newly_detected] }).only_newly_detected_licenses?).to be(true)
    end

    it 'is false when other states are present' do
      rule = described_class.new({ license_states: %w[newly_detected detected] })
      expect(rule.only_newly_detected_licenses?).to be(false)
    end

    it { expect(described_class.new({}).only_newly_detected_licenses?).to be(false) }
  end

  describe '#commits_any? and #commits_unsigned?' do
    it 'reports any' do
      rule = described_class.new({ commits: 'any' })
      expect(rule.commits_any?).to be(true)
      expect(rule.commits_unsigned?).to be(false)
    end

    it 'reports unsigned' do
      rule = described_class.new({ commits: 'unsigned' })
      expect(rule.commits_any?).to be(false)
      expect(rule.commits_unsigned?).to be(true)
    end

    it 'returns false when unset' do
      rule = described_class.new({})
      expect(rule.commits_any?).to be(false)
      expect(rule.commits_unsigned?).to be(false)
    end
  end

  describe '#match_on_inclusion_license' do
    it 'returns the match_on_inclusion_license value' do
      rule = described_class.new({ match_on_inclusion_license: true })
      expect(rule.match_on_inclusion_license).to be true
    end
  end

  describe '#license_types' do
    context 'when license_types is present' do
      it 'returns the license_types array' do
        rule = described_class.new({ license_types: ['MIT', 'Apache-2.0'] })
        expect(rule.license_types).to match_array(['MIT', 'Apache-2.0'])
      end
    end

    context 'when license_types is not present' do
      it 'returns an empty array' do
        rule = described_class.new({})
        expect(rule.license_types).to be_empty
      end
    end
  end

  describe '#license_states' do
    context 'when license_states is present' do
      it 'returns the license_states array' do
        rule = described_class.new({ license_states: %w[detected newly_detected] })
        expect(rule.license_states).to match_array(%w[detected newly_detected])
      end
    end

    context 'when license_states is not present' do
      it 'returns an empty array' do
        rule = described_class.new({})
        expect(rule.license_states).to be_empty
      end
    end
  end

  describe '#licenses' do
    context 'when licenses is present' do
      let(:allowed_licenses) do
        {
          allowed: [
            {
              name: 'MIT License',
              packages: { excluding: { purls: ['pkg:gem/bundler@1.0.0'] } }
            }
          ]
        }
      end

      it 'returns the licenses hash' do
        rule = described_class.new(licenses: allowed_licenses)
        expect(rule.licenses).to eq(allowed_licenses)
      end
    end

    context 'when licenses is not present' do
      it 'returns an empty hash' do
        rule = described_class.new({})
        expect(rule.licenses).to be_empty
      end
    end
  end

  describe '#scanner_configurations' do
    let(:rule_vulnerability_attributes) { { fix_available: true } }
    let(:rule_severity_levels) { %w[critical high] }
    let(:rule_vulnerabilities_allowed) { 5 }
    let(:rule_vulnerability_states) { %w[detected confirmed] }
    let(:rule_hash) do
      {
        scanners: scanners,
        vulnerability_attributes: rule_vulnerability_attributes,
        severity_levels: rule_severity_levels,
        vulnerabilities_allowed: rule_vulnerabilities_allowed,
        vulnerability_states: rule_vulnerability_states
      }
    end

    subject(:scanner_configurations) do
      described_class.new(rule_hash).scanner_configurations
    end

    context 'with legacy scanner format (string array)' do
      let(:scanners) { %w[sast dependency_scanning] }

      it 'returns scanner configs with rule-level attributes', :aggregate_failures do
        expect(scanner_configurations.map(&:type)).to contain_exactly('sast', 'dependency_scanning')
        expect(scanner_configurations.map(&:vulnerability_attributes)).to all(eq(rule_vulnerability_attributes))
        expect(scanner_configurations.map(&:severity_levels)).to all(eq(rule_severity_levels))
        expect(scanner_configurations.map(&:vulnerabilities_allowed)).to all(eq(rule_vulnerabilities_allowed))
        expect(scanner_configurations.map(&:vulnerability_states)).to all(eq(rule_vulnerability_states))
        expect(scanner_configurations.map(&:is_malicious)).to all(be false)
      end
    end

    context 'with scanner-level is_malicious' do
      let(:scanners) do
        [
          { 'type' => 'dependency_scanning', 'is_malicious' => true },
          { 'type' => 'container_scanning' }
        ]
      end

      it 'reads is_malicious per scanner, defaulting to false', :aggregate_failures do
        ds_config = scanner_configurations.find { |c| c.type == 'dependency_scanning' }
        cs_config = scanner_configurations.find { |c| c.type == 'container_scanning' }

        expect(ds_config.is_malicious).to be true
        expect(cs_config.is_malicious).to be false
      end
    end

    context 'with new scanner format (object array)' do
      let(:scanners) do
        [
          { 'type' => 'sast', 'vulnerability_attributes' => { 'fix_available' => false, 'known_exploited' => true },
            'severity_levels' => %w[low info], 'vulnerabilities_allowed' => 10,
            'vulnerability_states' => %w[new_needs_triage] },
          { 'type' => 'dependency_scanning',
            'vulnerability_attributes' => { 'epss_score' => { 'operator' => 'greater_than', 'value' => 0.5 } } },
          { 'type' => 'container_scanning' }
        ]
      end

      it 'returns scanner configs with scanner-specific attributes' do
        sast_config = scanner_configurations.find { |c| c.type == 'sast' }
        ds_config = scanner_configurations.find { |c| c.type == 'dependency_scanning' }
        cs_config = scanner_configurations.find { |c| c.type == 'container_scanning' }

        expect(sast_config.vulnerability_attributes).to eq({ fix_available: false, known_exploited: true })
        expect(sast_config.severity_levels).to eq(%w[low info])
        expect(sast_config.vulnerabilities_allowed).to eq(10)
        expect(sast_config.vulnerability_states).to eq(%w[new_needs_triage])

        expect(ds_config.vulnerability_attributes).to eq({ epss_score: { operator: 'greater_than', value: 0.5 } })
        expect(ds_config.severity_levels).to eq(rule_severity_levels)
        expect(ds_config.vulnerabilities_allowed).to eq(rule_vulnerabilities_allowed)
        expect(ds_config.vulnerability_states).to eq(rule_vulnerability_states)

        expect(cs_config.vulnerability_attributes).to eq(rule_vulnerability_attributes)
        expect(cs_config.severity_levels).to eq(rule_severity_levels)
        expect(cs_config.vulnerabilities_allowed).to eq(rule_vulnerabilities_allowed)
        expect(cs_config.vulnerability_states).to eq(rule_vulnerability_states)
      end
    end

    context 'with mixed format' do
      let(:scanners) do
        [
          'sast',
          { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'known_exploited' => true },
            'severity_levels' => %w[medium], 'vulnerability_states' => %w[dismissed] }
        ]
      end

      it 'handles both string and object scanners' do
        sast_config = scanner_configurations.find { |c| c.type == 'sast' }
        ds_config = scanner_configurations.find { |c| c.type == 'dependency_scanning' }

        expect(sast_config.vulnerability_attributes).to eq(rule_vulnerability_attributes)
        expect(sast_config.severity_levels).to eq(rule_severity_levels)
        expect(sast_config.vulnerabilities_allowed).to eq(rule_vulnerabilities_allowed)
        expect(sast_config.vulnerability_states).to eq(rule_vulnerability_states)

        expect(ds_config.vulnerability_attributes).to eq({ known_exploited: true })
        expect(ds_config.severity_levels).to eq(%w[medium])
        expect(ds_config.vulnerabilities_allowed).to eq(rule_vulnerabilities_allowed)
        expect(ds_config.vulnerability_states).to eq(%w[dismissed])
      end
    end
  end

  describe '#has_scanner_overrides?' do
    subject(:has_scanner_overrides) do
      described_class.new({ scanners: scanners }).has_scanner_overrides?
    end

    context 'when no scanner has any per-scanner attributes' do
      let(:scanners) do
        [
          { 'type' => 'sast' },
          { 'type' => 'dependency_scanning' }
        ]
      end

      it { expect(has_scanner_overrides).to be false }
    end

    context 'when at least one scanner has vulnerability_attributes' do
      let(:scanners) do
        [
          { 'type' => 'sast' },
          { 'type' => 'dependency_scanning', 'vulnerability_attributes' => { 'fix_available' => true } }
        ]
      end

      it { expect(has_scanner_overrides).to be true }
    end

    context 'when at least one scanner has severity_levels' do
      let(:scanners) do
        [
          { 'type' => 'sast', 'severity_levels' => %w[critical] }
        ]
      end

      it { expect(has_scanner_overrides).to be true }
    end

    context 'when at least one scanner has vulnerabilities_allowed' do
      let(:scanners) do
        [
          { 'type' => 'sast', 'vulnerabilities_allowed' => 3 }
        ]
      end

      it { expect(has_scanner_overrides).to be true }
    end

    context 'when at least one scanner has vulnerability_states' do
      let(:scanners) do
        [
          { 'type' => 'sast', 'vulnerability_states' => %w[new_needs_triage] }
        ]
      end

      it { expect(has_scanner_overrides).to be true }
    end

    context 'when vulnerability_states is empty' do
      let(:scanners) do
        [
          { 'type' => 'sast', 'vulnerability_states' => [] }
        ]
      end

      it { expect(has_scanner_overrides).to be false }
    end

    context 'when at least one scanner has is_malicious set' do
      let(:scanners) do
        [
          { 'type' => 'sast', 'is_malicious' => true }
        ]
      end

      it { expect(has_scanner_overrides).to be true }
    end

    context 'when is_malicious is false' do
      let(:scanners) do
        [
          { 'type' => 'sast', 'is_malicious' => false }
        ]
      end

      it { expect(has_scanner_overrides).to be false }
    end

    context 'with legacy string format' do
      let(:scanners) { %w[sast dependency_scanning] }

      it { expect(has_scanner_overrides).to be false }
    end
  end

  describe '#has_enrichment_filters?' do
    subject(:has_enrichment_filters) { described_class.new(rule).has_enrichment_filters? }

    context 'with rule-level vulnerability_attributes' do
      where(:vulnerability_attributes, :expected) do
        [
          [{ known_exploited: true },                                    true],
          [{ known_exploited: false },                                   true],
          [{ epss_score: { operator: 'greater_than', value: 0.5 } }, true],
          [{ fix_available: true },                                      false],
          [{},                                                           false]
        ]
      end

      with_them do
        let(:rule) { { vulnerability_attributes: vulnerability_attributes } }

        it { is_expected.to eq(expected) }
      end
    end

    context 'with atomic scanner-level vulnerability_attributes' do
      context 'when a scanner has known_exploited' do
        let(:rule) do
          { scanners: [{ 'type' => 'sast', 'vulnerability_attributes' => { 'known_exploited' => true } }] }
        end

        it { is_expected.to be true }
      end

      context 'when a scanner has epss_score' do
        let(:rule) do
          { scanners: [{ 'type' => 'sast',
                         'vulnerability_attributes' => { 'epss_score' => { 'operator' => 'greater_than',
                                                                           'value' => 0.5 } } }] }
        end

        it { is_expected.to be true }
      end

      context 'when a scanner falls back to rule-level known_exploited' do
        let(:rule) do
          { vulnerability_attributes: { known_exploited: true }, scanners: [{ 'type' => 'sast' }] }
        end

        it { is_expected.to be true }
      end

      context 'when no scanner has enrichment filters and rule-level has none' do
        let(:rule) do
          { scanners: [{ 'type' => 'sast', 'vulnerability_attributes' => { 'fix_available' => true } }] }
        end

        it { is_expected.to be false }
      end
    end
  end
end
