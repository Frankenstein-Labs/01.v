# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::Advisory, type: :model, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  subject(:advisory) { build(:pm_advisory) }

  describe 'validations' do
    it_behaves_like 'model with cvss v2 vector validation', :cvss_v2
    it_behaves_like 'model with cvss v3 vector validation', :cvss_v3
    it_behaves_like 'model with cvss v4 vector validation', :cvss_v4

    it { is_expected.to validate_presence_of(:advisory_xid) }
    it { is_expected.to validate_presence_of(:source_xid) }
    it { is_expected.to validate_presence_of(:published_date) }
    it { is_expected.to allow_value(nil).for(:cvss_v2) }
    it { is_expected.to allow_value(nil).for(:cvss_v3) }
    it { is_expected.to allow_value(nil).for(:cvss_v4) }
    it { is_expected.not_to allow_value('').for(:cvss_v2) }
    it { is_expected.not_to allow_value('').for(:cvss_v3) }
    it { is_expected.not_to allow_value('').for(:cvss_v4) }

    describe 'length validation' do
      where(:attribute, :value, :is_valid) do
        :advisory_xid | ('a' * 36)            | true
        :advisory_xid | ('a' * 37)            | false
        :title        | ('a' * 256)           | true
        :title        | ('a' * 257)           | false
        :description  | ('a' * 8192)          | true
        :description  | ('a' * 8193)          | false
        :urls         | ['a' * 512]           | true
        :urls         | ['a' * 513]           | false
        :urls         | Array.new(20) { 'a' } | true
        :urls         | Array.new(21) { 'a' } | false
      end

      with_them do
        subject(:advisory) { build(:pm_advisory, attribute => value).valid? }

        it { is_expected.to eq(is_valid) }
      end
    end

    describe 'identifier validation' do
      subject { build(:pm_advisory, identifiers: identifiers) }

      context 'when properly formatted list of identifiers' do
        let(:identifiers) do
          [
            create(:pm_identifier, :cve),
            create(:pm_identifier, type: "ghsa", name: "GHSA-9445-4cr6-336r", value: "GHSA-9445-4cr6-336r", url: "https://nvd.nist.gov/vuln/detail/CVE-2023-22797"),
            create(:pm_identifier, type: "gms", name: "GMS-2023-57", value: "GMS-2023-57")
          ]
        end

        it { is_expected.to be_valid }
      end

      context 'when more than max identifiers' do
        let(:identifiers) { create_list(:pm_identifier, 11, :cve) }

        it { is_expected.not_to be_valid }
      end

      context 'when identifier' do
        let(:base_identifier) do
          create(:pm_identifier, :cve)
        end

        let(:identifiers) { [identifier] }

        context 'with missing type' do
          let(:identifier) { base_identifier.reject { |k, _| k == 'type' } }

          it { is_expected.not_to be_valid }
        end

        context 'with missing name' do
          let(:identifier) { base_identifier.reject { |k, _| k == 'name' } }

          it { is_expected.not_to be_valid }
        end

        context 'with missing url' do
          let(:identifier) { base_identifier.reject { |k, _| k == 'url' } }

          it { is_expected.to be_valid }
        end

        context 'with missing value' do
          let(:identifier) { base_identifier.reject { |k, _| k == 'value' } }

          it { is_expected.not_to be_valid }
        end
      end
    end

    describe 'cve validation' do
      it { is_expected.to allow_value('CVE-2023-12345').for(:cve) }
      it { is_expected.to allow_value('CVE-2023-123456789012345').for(:cve) }
      it { is_expected.not_to allow_value('CVE-2023-123').for(:cve) }
      it { is_expected.not_to allow_value('CVE-2023-123456789876543212345678987654321').for(:cve) }
      it { is_expected.not_to allow_value('CVE-23-12345').for(:cve) }
      it { is_expected.not_to allow_value('cve-2023-12345').for(:cve) }
      it { is_expected.not_to allow_value('NOT-A-CVE').for(:cve) }
      it { is_expected.to allow_value(nil).for(:cve) }
      it { is_expected.not_to allow_value('').for(:cve) }
    end
  end

  describe '#from_container_scanning?' do
    subject { advisory.from_container_scanning? }

    context 'when source_xid is trivy-db' do
      let(:advisory) { build(:pm_advisory, source_xid: 'trivy-db') }

      it { is_expected.to be true }
    end

    context 'when source_xid is not trivy-db' do
      let(:advisory) { build(:pm_advisory, source_xid: 'glad') }

      it { is_expected.to be false }
    end
  end

  describe '.find_by_identifier' do
    let_it_be(:advisory) do
      create(:pm_advisory, identifiers: [
        { type: 'CVE', name: 'CVE-2024-1234', value: 'CVE-2024-1234', url: 'https://example.com/cve' },
        { type: 'GHSA', name: 'GHSA-xxxx-yyyy', value: 'GHSA-xxxx-yyyy', url: 'https://example.com/ghsa' }
      ])
    end

    context 'when identifier exists' do
      it 'returns the advisory by CVE identifier' do
        result = described_class.find_by_identifier('CVE-2024-1234')
        expect(result).to eq(advisory)
      end

      it 'returns the advisory by GHSA identifier' do
        result = described_class.find_by_identifier('GHSA-xxxx-yyyy')
        expect(result).to eq(advisory)
      end
    end

    context 'when identifier does not exist' do
      it 'returns nil' do
        result = described_class.find_by_identifier('CVE-9999-9999')
        expect(result).to be_nil
      end
    end
  end

  describe '.by_identifiers' do
    let_it_be(:advisory_1) do
      create(:pm_advisory, identifiers: [
        { type: 'CVE', name: 'CVE-2024-1234', value: 'CVE-2024-1234', url: 'https://example.com/cve1' }
      ])
    end

    let_it_be(:advisory_2) do
      create(:pm_advisory, identifiers: [
        { type: 'CVE', name: 'CVE-2024-5678', value: 'CVE-2024-5678', url: 'https://example.com/cve2' }
      ])
    end

    context 'when all identifiers exist' do
      it 'returns all matching advisories' do
        result = described_class.by_identifiers(%w[CVE-2024-1234 CVE-2024-5678])
        expect(result).to contain_exactly(advisory_1, advisory_2)
      end
    end

    context 'when some identifiers exist' do
      it 'returns only matching advisories' do
        result = described_class.by_identifiers(%w[CVE-2024-1234 CVE-9999-9999])
        expect(result).to contain_exactly(advisory_1)
      end
    end

    context 'when no identifiers exist' do
      it 'returns empty array' do
        result = described_class.by_identifiers(%w[CVE-9999-9999 CVE-8888-8888])
        expect(result).to be_empty
      end
    end

    context 'when identifiers array is empty' do
      it 'returns empty array' do
        result = described_class.by_identifiers([])
        expect(result).to be_empty
      end
    end
  end
end
