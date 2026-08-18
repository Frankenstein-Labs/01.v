# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::FetchPackageVulnerabilitiesService,
  feature_category: :dependency_firewall do
  subject(:result) { described_class.new(name: name, purl_type: purl_type, version: version).execute }

  let(:purl_type) { 'npm' }
  let(:name) { 'lodash' }
  let(:version) { '4.17.21' }

  describe '#execute' do
    context 'when no affected package matches the (purl_type, name)' do
      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end

    context 'when version is nil' do
      let(:version) { nil }

      before do
        create(:pm_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'returns advisories regardless of affected_range' do
        expect(result.length).to eq(1)
      end
    end

    context 'when the version matcher raises SemverDialects::Error for an advisory' do
      before do
        create(:pm_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')

        allow_next_instance_of(
          Gitlab::VulnerabilityScanning::DependencyScanning::AffectedVersionRangeMatcher
        ) do |matcher|
          allow(matcher).to receive(:affected?).and_raise(SemverDialects::Error.new('boom'))
        end
      end

      it 'skips that advisory rather than propagating the error' do
        expect { result }.not_to raise_error
        expect(result).to eq([])
      end
    end

    context 'when the version is outside the affected_range' do
      let(:version) { '6.0.0' }

      before do
        create(:pm_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'excludes the advisory' do
        expect(result).to eq([])
      end
    end

    context 'when the advisory has multiple identifiers including a CVE that is not first' do
      let(:advisory) do
        create(:pm_advisory,
          identifiers: [
            { type: 'gemnasium', name: 'Gemnasium-abc', value: 'abc', url: 'https://example.com' },
            { type: 'cve', name: 'CVE-2099-9999', value: 'CVE-2099-9999', url: 'https://example.com' }
          ])
      end

      before do
        create(:pm_affected_package,
          advisory: advisory,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'returns the CVE identifier as :id' do
        expect(result.first[:id]).to eq('CVE-2099-9999')
      end
    end

    context 'when the advisory has no valid CVSS vectors' do
      let(:advisory) { create(:pm_advisory, cvss_v2: nil, cvss_v3: nil, cvss_v4: nil) }

      before do
        create(:pm_affected_package,
          advisory: advisory,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'returns severity unknown' do
        expect(result.first[:severity]).to eq('unknown')
      end
    end

    context 'when an affected package matches the (purl_type, name) and version is in range' do
      let(:advisory) do
        create(:pm_advisory,
          identifiers: [
            { type: 'cve', name: 'CVE-2099-0001', value: 'CVE-2099-0001', url: 'https://example.com' }
          ])
      end

      before do
        create(:pm_affected_package,
          advisory: advisory,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'returns a single hash with :id and :severity for the advisory' do
        expect(result.length).to eq(1)
        expect(result.first).to include(:id, :severity)
        expect(result.first[:id]).to eq('CVE-2099-0001')
        expect(result.first[:severity]).to be_in(%w[critical high medium low info unknown])
      end
    end
  end
end
