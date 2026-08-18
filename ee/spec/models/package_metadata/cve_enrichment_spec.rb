# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::CveEnrichment, type: :model, feature_category: :software_composition_analysis do
  using RSpec::Parameterized::TableSyntax

  subject(:cve_enrichment) { build(:pm_cve_enrichment) }

  describe 'associations' do
    it { is_expected.to have_many(:identifiers).class_name('Vulnerabilities::Identifier') }

    it 'has many finding enrichments' do
      is_expected.to have_many(:finding_enrichments)
                      .class_name('Security::FindingEnrichment')
                      .inverse_of(:cve_enrichment)
    end

    it 'has many security findings through finding enrichments' do
      is_expected.to have_many(:security_findings)
                      .through(:finding_enrichments)
                      .source(:security_finding)
                      .class_name('Security::Finding')
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:cve) }
    it { is_expected.to validate_presence_of(:epss_score) }
    it { is_expected.to validate_inclusion_of(:is_known_exploit).in_array([true, false]) }

    describe 'CVE format validation' do
      where(:attribute, :value, :is_valid) do
        :cve | 'CVE-1234-1234'                 | true
        :cve | 'CVE-2024-123456'               | true
        :cve | 'CVE-12-1234'                   | false
        :cve | 'CVE-1234-12345678901234567890' | false
        :cve | 'IAM-NOTA-CVE!'                 | false
      end

      with_them do
        subject(:cve_enrichment) { build(:pm_cve_enrichment, attribute => value).valid? }

        it { is_expected.to eq(is_valid) }
      end
    end
  end

  describe 'scopes' do
    describe '.updated_after' do
      let_it_be(:old_cve) { create(:pm_cve_enrichment, updated_at: 2.days.ago) }
      let_it_be(:recent_cve) { create(:pm_cve_enrichment, updated_at: 1.hour.ago) }
      let_it_be(:very_recent_cve) { create(:pm_cve_enrichment, updated_at: 1.minute.ago) }

      context 'when there are CVE enrichments updated after the given time' do
        subject(:cve_enrichments) { described_class.updated_after(1.day.ago) }

        it 'returns enrichments updated after the given time' do
          expect(cve_enrichments).to contain_exactly(recent_cve, very_recent_cve)
        end
      end

      context 'when all CVE enrichments are updated after the given time' do
        subject(:cve_enrichments) { described_class.updated_after(3.days.ago) }

        it 'returns all enrichments' do
          expect(cve_enrichments).to contain_exactly(old_cve, recent_cve, very_recent_cve)
        end
      end

      shared_examples_for 'returns none' do
        it 'returns empty result' do
          expect(cve_enrichments).to be_empty
        end
      end

      context 'when there are no CVE enrichments updated after the given time' do
        subject(:cve_enrichments) { described_class.updated_after(1.minute.ago) }

        it_behaves_like 'returns none'
      end

      context 'when the time is in the future' do
        subject(:cve_enrichments) { described_class.updated_after(1.day.from_now) }

        it_behaves_like 'returns none'
      end
    end
  end

  describe '.pluck_id' do
    let_it_be(:cve_1) { create(:pm_cve_enrichment) }
    let_it_be(:cve_2) { create(:pm_cve_enrichment) }
    let_it_be(:cve_3) { create(:pm_cve_enrichment) }

    subject(:cve_enrichment_ids) { described_class.pluck_id(limit) }

    context 'when a limit is provided' do
      let(:limit) { 2 }

      it 'respects the limit parameter' do
        expect(cve_enrichment_ids.count).to eq(limit)
      end
    end

    context 'when a limit is not provided' do
      subject(:cve_enrichment_ids) { described_class.pluck_id }

      before do
        stub_const("#{described_class}::MAX_PLUCK", 1)
      end

      it 'uses MAX_PLUCK as default limit' do
        expect(cve_enrichment_ids.count).to eq(1)
      end
    end
  end
end
