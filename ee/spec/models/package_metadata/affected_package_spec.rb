# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::AffectedPackage, type: :model, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  subject(:advisory) { build(:pm_affected_package) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:purl_type) }
    it { is_expected.to validate_presence_of(:package_name) }
    it { is_expected.to validate_presence_of(:affected_range) }
    it { is_expected.to allow_value(['x'] * 10).for(:fixed_versions) }
    it { is_expected.not_to allow_value(['x'] * 11).for(:fixed_versions) }

    describe 'length validation' do
      where(:attribute, :max_length) do
        :affected_range | 512
        :solution | 2048
      end

      with_them do
        it { is_expected.to validate_length_of(attribute).is_at_most(max_length) }
      end
    end

    describe 'overridden_advisory_fields' do
      subject { build(:pm_affected_package, overridden_advisory_fields: fields) }

      let(:fields) do
        {
          field_name => field_value
        }
      end

      context 'when empty' do
        let(:fields) { {} }

        it { is_expected.to be_valid }
      end

      context 'when attribute is well formed' do
        where(:field_name, :field_value) do
          [
            [:published_date, '2023-04-25'],
            [:title, 'Information exposure'],
            [:description, 'A description with `markdown`'],
            [:cvss_v2, 'AV:N/AC:M/Au:N/C:N/I:P/A:P'],
            [:cvss_v3, 'CVSS:3.1/AV:N/AC:H/PR:L/UI:N/S:C/C:N/I:L/A:L'],
            [:cvss_v4, 'CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N'],
            [:identifiers, [{ type: 'foo', name: 'bar', value: 'baz' }]],
            [:urls, ["https://nvd.nist.gov/vuln/detail/CVE-2019-3888",
              "https://bugzilla.redhat.com/show_bug.cgi?id=CVE-2019-3888"]]
          ]
        end

        with_them do
          it { is_expected.to be_valid }
        end
      end

      context 'when attribute is not well formed' do
        where(:field_name, :field_value) do
          [
            [:published_date, '1927374'],
            [:title, 'a' * 257],
            [:description, 'a' * 8193],
            [:cvss_v2, 'foo'],
            [:cvss_v3, 'bar'],
            [:identifiers, [{ type: 'foo', name: 'bar' }]],
            [:urls, [123]],
            [:urls, ['a' * 513]]
          ]
        end

        with_them do
          it { is_expected.not_to be_valid }
        end
      end
    end

    describe 'versions' do
      subject { build(:pm_affected_package, versions: versions).valid? }

      let(:valid_sha) { '295cf0778821bf08681e2bd0ef0e6cad04fc3001' }
      let(:valid_timestamp) { '20190626162700' }
      let(:valid_number) { '1.2.3' }
      let(:valid_tags) { ['v1.2.3-tag'] }
      let(:valid_num_versions) { 1 }

      # rubocop:disable Layout/LineLength
      where(:number, :tags, :sha, :timestamp, :num_versions, :is_valid) do
        ref(:valid_number) | ref(:valid_tags) | ref(:valid_sha) | ref(:valid_timestamp) | 0                        | true
        ref(:valid_number) | ref(:valid_tags) | ref(:valid_sha) | ref(:valid_timestamp) | 32                       | true
        ref(:valid_number) | ref(:valid_tags) | ref(:valid_sha) | ref(:valid_timestamp) | 33                       | false
        ref(:valid_number) | ['']             | ref(:valid_sha) | ref(:valid_timestamp) | ref(:valid_num_versions) | true
        ref(:valid_number) | [('a' * 32)]     | ref(:valid_sha) | ref(:valid_timestamp) | ref(:valid_num_versions) | true
        ref(:valid_number) | []               | ref(:valid_sha) | ref(:valid_timestamp) | ref(:valid_num_versions) | true
        ref(:valid_number) | (['a'] * 16)     | ref(:valid_sha) | ref(:valid_timestamp) | ref(:valid_num_versions) | true
        ref(:valid_number) | (['a'] * 17)     | ref(:valid_sha) | ref(:valid_timestamp) | ref(:valid_num_versions) | false
        ref(:valid_number) | [('a' * 33)]     | ref(:valid_sha) | ref(:valid_timestamp) | ref(:valid_num_versions) | false
        ''                 | ref(:valid_tags) | ref(:valid_sha) | ref(:valid_timestamp) | ref(:valid_num_versions) | false
        ref(:valid_number) | ref(:valid_tags) | ('a' * 4)       | ref(:valid_timestamp) | ref(:valid_num_versions) | false
        ref(:valid_number) | ref(:valid_tags) | ('a' * 41)      | ref(:valid_timestamp) | ref(:valid_num_versions) | false
        ref(:valid_number) | ref(:valid_tags) | ref(:valid_sha) | '2019062616270'       | ref(:valid_num_versions) | false
        ref(:valid_number) | ref(:valid_tags) | ref(:valid_sha) | '2019062616270a'      | ref(:valid_num_versions) | false
        ref(:valid_number) | ref(:valid_tags) | ref(:valid_sha) | '201906261627001'     | ref(:valid_num_versions) | false
      end
      # rubocop:enable Layout/LineLength

      with_them do
        let(:versions) { [{ number: number, commit: { tags: tags, sha: sha, timestamp: timestamp } }] * num_versions }

        it { is_expected.to eq(is_valid) }
      end
    end
  end

  describe '.for_occurrences' do
    let_it_be(:occurrences) { create_list(:sbom_occurrence, 3) }
    let_it_be(:unrelated_occurrence) { create(:sbom_occurrence) }
    let_it_be(:unrelated_affected_package) do
      create(:pm_affected_package, purl_type: unrelated_occurrence.purl_type,
        package_name: unrelated_occurrence.component_name)
    end

    let_it_be(:affected_packages) do
      occurrences.map do |occurrence|
        create(:pm_affected_package, purl_type: occurrence.purl_type, package_name: occurrence.component_name)
      end
    end

    it 'returns only related occurrences' do
      expect(described_class.for_occurrences(occurrences)).to eq(affected_packages)
    end

    it 'does not return unrelated occurrences' do
      expect(described_class.for_occurrences(occurrences)).not_to include(unrelated_affected_package)
    end

    context 'with sbom pipeline components' do
      let(:sbom_components) do
        occurrences.map do |occurrence|
          build(:ci_reports_sbom_component, purl_type: occurrence.purl_type, name: occurrence.component_name)
        end
      end

      it 'returns only related occurrences' do
        expect(described_class.for_occurrences(sbom_components)).to eq(affected_packages)
      end

      it 'does not return unrelated occurrences' do
        expect(described_class.for_occurrences(sbom_components)).not_to include(unrelated_affected_package)
      end
    end
  end

  describe '#solution_text' do
    subject { affected_package.solution_text }

    let(:affected_package) do
      build(:pm_affected_package, solution: 'Update version')
    end

    context 'with solution present' do
      it { is_expected.to eq('Update version') }
    end

    context 'without fixed versions' do
      let(:affected_package) do
        build(:pm_affected_package, solution: nil, fixed_versions: [])
      end

      it { is_expected.to eq('Unfortunately, there is no solution available yet.') }
    end

    context 'with fixed versions' do
      let(:fixed_version) { '1.2.3' }
      let(:affected_package) do
        build(:pm_affected_package, solution: nil, fixed_versions: [fixed_version])
      end

      it { is_expected.to match(/Upgrade to version #{fixed_version} or above/) }
    end
  end
end
