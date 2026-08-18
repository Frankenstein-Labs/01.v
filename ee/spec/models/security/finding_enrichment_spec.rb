# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::FindingEnrichment, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:scan)    { create(:security_scan, project: project) }
  let_it_be(:security_finding) { create(:security_finding, scan: scan) }

  subject { build(:security_finding_enrichment, project: project, security_finding: security_finding) }

  describe 'associations' do
    it { is_expected.to belong_to(:project).class_name('Project').required }

    it 'belongs to security finding' do
      is_expected.to belong_to(:security_finding)
                      .class_name('Security::Finding')
                      .with_primary_key('uuid')
                      .with_foreign_key('finding_uuid')
                      .inverse_of(:finding_enrichments)
                      .required
    end

    it 'belongs to vulnerability finding' do
      is_expected.to belong_to(:vulnerability_finding)
                      .class_name('Vulnerabilities::Finding')
                      .with_primary_key('uuid')
                      .with_foreign_key('finding_uuid')
                      .inverse_of(:security_finding_enrichments)
                      .optional
    end

    it 'belongs to CVE enrichment' do
      is_expected.to belong_to(:cve_enrichment)
                      .class_name('PackageMetadata::CveEnrichment')
                      .inverse_of(:finding_enrichments)
                      .optional
    end

    it 'belongs to vulnerability' do
      is_expected.to belong_to(:vulnerability)
                      .class_name('::Vulnerability')
                      .inverse_of(:security_finding_enrichments)
                      .optional
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:cve) }
    it { is_expected.to validate_uniqueness_of(:finding_uuid).scoped_to(:cve).ignoring_case_sensitivity }

    describe 'cve format validation' do
      it { is_expected.to allow_value('CVE-2024-1234').for(:cve) }
      it { is_expected.to allow_value('CVE-2024-12345').for(:cve) }
      it { is_expected.to allow_value('CVE-2024-123456789012345').for(:cve) }
      it { is_expected.not_to allow_value('CVE-2024-123').for(:cve) }
      it { is_expected.not_to allow_value('CVE-24-1234').for(:cve) }
      it { is_expected.not_to allow_value('cve-2024-1234').for(:cve) }
      it { is_expected.not_to allow_value('2024-1234').for(:cve) }
      it { is_expected.not_to allow_value('CVE-2024-1234567890123456').for(:cve) }
    end
  end

  describe 'scopes' do
    describe '.with_known_exploited' do
      let_it_be(:enrichment_exploited) do
        create(:security_finding_enrichment, project: project, security_finding: security_finding,
          is_known_exploit: true)
      end

      let_it_be(:enrichment_not_exploited) do
        create(:security_finding_enrichment, project: project,
          is_known_exploit: false)
      end

      it 'returns enrichments with known exploits when true' do
        expect(described_class.with_known_exploited(true)).to contain_exactly(enrichment_exploited)
      end

      it 'returns enrichments without known exploits when false' do
        expect(described_class.with_known_exploited(false)).to contain_exactly(enrichment_not_exploited)
      end
    end

    describe '.with_epss_score' do
      let_it_be(:enrichment_high_score) do
        create(:security_finding_enrichment, project: project, security_finding: security_finding,
          epss_score: 0.9)
      end

      let_it_be(:enrichment_medium_score) do
        create(:security_finding_enrichment, project: project,
          epss_score: 0.5)
      end

      let_it_be(:enrichment_low_score) do
        create(:security_finding_enrichment, project: project,
          epss_score: 0.1)
      end

      context 'with greater_than operator' do
        it 'returns enrichments with EPSS score greater than threshold' do
          expect(described_class.with_epss_score(:greater_than, 0.5))
            .to contain_exactly(enrichment_high_score)
        end
      end

      context 'with less_than operator' do
        it 'returns enrichments with EPSS score less than threshold' do
          expect(described_class.with_epss_score(:less_than, 0.5))
            .to contain_exactly(enrichment_low_score)
        end
      end

      context 'with invalid operator' do
        it 'raises an error' do
          expect { described_class.with_epss_score(:invalid_operator, 0.5) }
            .to raise_error(ArgumentError, 'Unsupported operator: invalid_operator')
        end
      end

      context 'when operator is nil' do
        it 'returns none' do
          expect(described_class.with_epss_score(nil, 0.5)).to eq(described_class.none)
        end
      end

      context 'when value is nil' do
        it 'returns none' do
          expect(described_class.with_epss_score(:greater_than, nil)).to eq(described_class.none)
        end
      end

      context 'when chaining scopes' do
        let_it_be(:enrichment_exploited_high_score) do
          create(:security_finding_enrichment, project: project,
            is_known_exploit: true, epss_score: 0.95)
        end

        it 'can be chained with other scopes' do
          result = described_class
            .with_known_exploited(true)
            .with_epss_score(:greater_than, 0.9)

          expect(result).to contain_exactly(enrichment_exploited_high_score)
        end
      end
    end

    describe '.by_cve_enrichment_id' do
      let_it_be(:cve_enrichment_1) { create(:pm_cve_enrichment) }
      let_it_be(:cve_enrichment_2) { create(:pm_cve_enrichment, cve: 'CVE-2023-11111') }

      let_it_be(:finding_enrichment_with_cve_1) do
        create(:security_finding_enrichment, project: project, security_finding: security_finding,
          cve_enrichment_id: cve_enrichment_1.id)
      end

      let_it_be(:finding_enrichment_with_cve_2) do
        create(:security_finding_enrichment, project: project,
          cve_enrichment_id: cve_enrichment_2.id)
      end

      let_it_be(:enrichment_without_cve) do
        create(:security_finding_enrichment, project: project,
          cve_enrichment_id: nil)
      end

      subject(:finding_enrichments_by_cve_enrichment_id) { described_class.by_cve_enrichment_id(cve_enrichment_ids) }

      context 'when querying for a single cve_enrichment_id' do
        let(:cve_enrichment_ids) { cve_enrichment_1.id }

        it 'returns finding enrichments with the specified CVE enrichment ID' do
          expect(finding_enrichments_by_cve_enrichment_id).to contain_exactly(finding_enrichment_with_cve_1)
        end
      end

      context 'when querying for a multiples cve_enrichment_id' do
        let(:cve_enrichment_ids) { [cve_enrichment_1.id, cve_enrichment_2.id] }

        it 'returns finding enrichments with any of the specified CVE enrichment IDs' do
          expect(finding_enrichments_by_cve_enrichment_id)
            .to contain_exactly(finding_enrichment_with_cve_1, finding_enrichment_with_cve_2)
        end
      end

      shared_examples_for 'returns none' do
        it 'returns none' do
          expect(finding_enrichments_by_cve_enrichment_id).to be_empty
        end
      end

      context 'when querying for non-existent cve_enrichment_id' do
        let(:cve_enrichment_ids) { non_existing_record_id }

        it_behaves_like 'returns none'
      end

      context 'when querying for an empty array of cve_enrichment_ids' do
        let(:cve_enrichment_ids) { [non_existing_record_id] }

        it_behaves_like 'returns none'
      end
    end

    describe '.with_enrichment_filters' do
      let_it_be(:enrichment_exploited_high_score) do
        create(:security_finding_enrichment, project: project,
          is_known_exploit: true, epss_score: 0.95)
      end

      let_it_be(:enrichment_not_exploited_low_score) do
        create(:security_finding_enrichment, project: project,
          is_known_exploit: false, epss_score: 0.2)
      end

      let_it_be(:enrichment_unknown_medium_score) do
        create(:security_finding_enrichment, project: project,
          is_known_exploit: nil, epss_score: 0.5)
      end

      it 'filters by known exploit status with known_exploited filter' do
        result = described_class.with_enrichment_filters(known_exploited: true)
        expect(result).to contain_exactly(enrichment_exploited_high_score)
      end

      it 'filters by EPSS score with epss_score filter' do
        result = described_class.with_enrichment_filters(epss_operator: :greater_than, epss_value: 0.5)
        expect(result).to contain_exactly(enrichment_exploited_high_score)
      end

      it 'applies both filters with both epss and kev filter' do
        result = described_class.with_enrichment_filters(
          known_exploited: true,
          epss_operator: :greater_than,
          epss_value: 0.9
        )
        expect(result).to contain_exactly(enrichment_exploited_high_score)
      end

      it 'returns none when known_exploited is false (filter not applied)' do
        result = described_class.with_enrichment_filters(known_exploited: false)
        expect(result).to eq(described_class.none)
      end

      it 'returns none with no filters' do
        result = described_class.with_enrichment_filters
        expect(result).to eq(described_class.none)
      end
    end

    describe '.for_finding_uuids' do
      let_it_be(:enrichment_1) do
        create(:security_finding_enrichment, project: project, security_finding: security_finding)
      end

      let_it_be(:other_security_finding) { create(:security_finding, scan: scan) }
      let_it_be(:enrichment_2) do
        create(:security_finding_enrichment, project: project, security_finding: other_security_finding)
      end

      let_it_be(:unrelated_enrichment) do
        create(:security_finding_enrichment, project: project)
      end

      it 'returns enrichments matching the given finding UUIDs' do
        uuids = [security_finding.uuid, other_security_finding.uuid]

        expect(described_class.for_finding_uuids(uuids)).to contain_exactly(enrichment_1, enrichment_2)
      end

      it 'returns empty when no UUIDs match' do
        expect(described_class.for_finding_uuids(['non-existent-uuid'])).to be_empty
      end

      it 'returns empty when given an empty array' do
        expect(described_class.for_finding_uuids([])).to be_empty
      end
    end

    describe '.stale' do
      let_it_be(:stale_enrichment) do
        create(:security_finding_enrichment, project: project,
          created_at: (Security::Scan.stale_after + 1.day).ago, vulnerability_id: nil)
      end

      let_it_be(:fresh_enrichment) do
        create(:security_finding_enrichment, project: project, created_at: 1.day.ago)
      end

      let_it_be(:stale_but_linked_enrichment) do
        create(:security_finding_enrichment, :with_vulnerability, project: project,
          created_at: (Security::Scan.stale_after + 1.day).ago)
      end

      it 'returns only enrichments older than the stale threshold without vulnerability link' do
        expect(described_class.stale).to contain_exactly(stale_enrichment)
      end
    end

    describe '.ordered_by_created_at_and_id' do
      let_it_be(:newer_enrichment) do
        create(:security_finding_enrichment, project: project, created_at: 1.day.ago)
      end

      let_it_be(:newer_enrichment_2) do
        create(:security_finding_enrichment, project: project, created_at: 1.day.ago)
      end

      let_it_be(:older_enrichment) do
        create(:security_finding_enrichment, project: project, created_at: 3.days.ago)
      end

      it 'returns enrichments ordered by created_at ascending, then id ascending' do
        result = described_class.ordered_by_created_at_and_id

        expect(result).to eq([older_enrichment, newer_enrichment, newer_enrichment_2])
      end
    end
  end
end
