# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::FetchPackageLicensesService,
  feature_category: :dependency_firewall do
  subject(:result) { described_class.new(name: name, purl_type: purl_type, version: version).execute }

  let(:purl_type) { 'maven' }
  let(:version) { '1.0.0' }

  describe '#execute' do
    context 'when version is nil and the package exists in the package metadata database' do
      let(:name) { 'com.example/trivial-lib' }
      let(:version) { nil }

      let_it_be(:pm_package) do
        create(:pm_package,
          name: 'com.example/trivial-lib',
          purl_type: 'maven',
          other_licenses: [{ license_names: ['Apache-2.0'], versions: ['1.0.0'] }])
      end

      it 'returns an empty licenses array' do
        expect(result).to be_empty
      end
    end

    context 'when the package is not found in the package metadata database' do
      let(:name) { 'com.example/unknown-lib' }

      it 'returns an empty licenses array' do
        expect(result).to be_empty
      end
    end

    context 'when PackageLicenses returns UNKNOWN_LICENSE' do
      let(:name) { 'com.example/some-lib' }

      before do
        allow_next_instance_of(::Gitlab::LicenseScanning::PackageLicenses) do |svc|
          allow(svc).to receive(:fetch).and_return(
            [Hashie::Mash.new(licenses: [::Gitlab::LicenseScanning::PackageLicenses::UNKNOWN_LICENSE])]
          )
        end
      end

      it 'excludes the unknown license sentinel' do
        expect(result).to be_empty
      end
    end

    context 'when a license has a blank spdx_identifier' do
      let(:name) { 'com.example/some-lib' }

      before do
        allow_next_instance_of(::Gitlab::LicenseScanning::PackageLicenses) do |svc|
          allow(svc).to receive(:fetch).and_return(
            [Hashie::Mash.new(licenses: [{ spdx_identifier: '', name: 'Unknown', url: nil }])]
          )
        end
      end

      it 'excludes licenses with blank identifiers' do
        expect(result).to be_empty
      end
    end

    context 'when a license has a nil spdx_identifier' do
      let(:name) { 'com.example/some-lib' }

      before do
        allow_next_instance_of(::Gitlab::LicenseScanning::PackageLicenses) do |svc|
          allow(svc).to receive(:fetch).and_return(
            [Hashie::Mash.new(licenses: [{ spdx_identifier: nil, name: 'Unknown', url: nil }])]
          )
        end
      end

      it 'excludes licenses with nil identifiers' do
        expect(result).to be_empty
      end
    end

    context 'with a package that has version-specific licenses' do
      let(:name) { 'com.example/trivial-lib' }

      let_it_be(:pm_package) do
        create(:pm_package,
          name: 'com.example/trivial-lib',
          purl_type: 'maven',
          other_licenses: [{ license_names: ['Apache-2.0'], versions: ['1.0.0'] }])
      end

      it 'returns the license for the requested version' do
        expect(result).to contain_exactly(
          a_hash_including(spdx_identifier: 'Apache-2.0', url: 'https://spdx.org/licenses/Apache-2.0.html')
        )
      end

      it 'returns plain Ruby hashes, not Hashie::Mash' do
        first = result.first
        expect(first).to be_a(Hash)
        expect(first).not_to be_a(Hashie::Mash)
      end
    end

    context 'with a package that has multiple licenses for the same version' do
      let(:name) { 'org.example/dual-licensed' }
      let(:version) { '2.0.0' }
      let(:purl_type) { 'maven' }

      let_it_be(:pm_package) do
        create(:pm_package,
          name: 'org.example/dual-licensed',
          purl_type: 'maven',
          other_licenses: [{ license_names: %w[MIT Apache-2.0], versions: ['2.0.0'] }])
      end

      it 'returns all licenses for the requested version' do
        expect(result).to contain_exactly(
          a_hash_including(spdx_identifier: 'MIT'),
          a_hash_including(spdx_identifier: 'Apache-2.0')
        )
      end
    end

    context 'with a package whose version falls within the default license range' do
      let(:name) { 'com.example/legacy-lib' }

      let_it_be(:pm_package) do
        create(:pm_package,
          name: 'com.example/legacy-lib',
          purl_type: 'maven',
          default_license_names: ['GPL-3.0-only'],
          other_licenses: [])
      end

      it 'returns the default license when no version-specific entry exists' do
        expect(result).to contain_exactly(
          a_hash_including(spdx_identifier: 'GPL-3.0-only')
        )
      end
    end

    context 'with a version outside the package metadata database range for that package' do
      let(:name) { 'com.example/versioned-lib' }
      let(:version) { '99.99.99' }

      let_it_be(:pm_package) do
        create(:pm_package,
          name: 'com.example/versioned-lib',
          purl_type: 'maven',
          other_licenses: [{ license_names: ['Apache-2.0'], versions: ['1.0.0'] }],
          lowest_version: '1.0.0',
          highest_version: '2.0.0')
      end

      it 'returns an empty licenses array' do
        expect(result).to be_empty
      end
    end

    context 'with a non-Maven package type' do
      let(:name) { 'lodash' }
      let(:purl_type) { 'npm' }
      let(:version) { '4.17.21' }

      let_it_be(:pm_package) do
        create(:pm_package,
          name: 'lodash',
          purl_type: 'npm',
          other_licenses: [{ license_names: ['MIT'], versions: ['4.17.21'] }])
      end

      it 'resolves licenses' do
        expect(result).to contain_exactly(a_hash_including(spdx_identifier: 'MIT'))
      end
    end

    context 'with a package whose name contains special characters' do
      let(:name) { '@gitlab-org/some-component' }
      let(:purl_type) { 'npm' }

      let_it_be(:pm_package) do
        create(:pm_package,
          name: '@gitlab-org/some-component',
          purl_type: 'npm',
          other_licenses: [{ license_names: ['MIT'], versions: ['1.0.0'] }])
      end

      it 'resolves licenses' do
        expect(result).to contain_exactly(a_hash_including(spdx_identifier: 'MIT'))
      end
    end
  end
end
