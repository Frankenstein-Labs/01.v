# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::DependencyFirewall::FetchPackageMaliciousService,
  feature_category: :dependency_firewall do
  subject(:result) { described_class.new(name: name, purl_type: purl_type, version: version).execute }

  let(:purl_type) { 'npm' }
  let(:name) { 'lodash' }
  let(:version) { '4.17.21' }

  describe '#execute' do
    context 'when no malicious advisory flags the package' do
      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end

    context 'when a malicious advisory flags the package and the version is in range' do
      let_it_be(:affected_package) do
        create(:pm_malware_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'returns the advisory wrapped in the { advisory: } contract shape' do
        expect(result).to contain_exactly({ advisory: affected_package.malware_advisory })
      end
    end

    context 'when multiple advisories flag the package' do
      let_it_be(:first_match) do
        create(:pm_malware_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      let_it_be(:second_match) do
        create(:pm_malware_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.17.0 <4.18.0')
      end

      it 'returns one advisory-bearing element per flagging advisory' do
        expect(result).to contain_exactly(
          { advisory: first_match.malware_advisory },
          { advisory: second_match.malware_advisory }
        )
      end
    end

    context 'when the version is blank' do
      let(:version) { nil }

      let_it_be(:affected_package) do
        create(:pm_malware_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'fails closed and returns the advisory regardless of range' do
        expect(result).to contain_exactly({ advisory: affected_package.malware_advisory })
      end
    end

    context 'when the version is outside every affected range' do
      let(:version) { '6.0.0' }

      before do
        create(:pm_malware_affected_package,
          purl_type: :npm,
          package_name: 'lodash',
          affected_range: '>=4.0.0 <5.0.0')
      end

      it 'returns an empty array' do
        expect(result).to eq([])
      end
    end
  end
end
