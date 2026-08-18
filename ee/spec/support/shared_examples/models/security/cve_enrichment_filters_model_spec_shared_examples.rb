# frozen_string_literal: true

RSpec.shared_examples 'CVE enrichment filters model spec' do
  context 'when filtering by known_exploited' do
    it 'returns records with known exploits when known_exploited is true' do
      expect(described_class.with_cve_enrichment_filters(known_exploited: true)).to contain_exactly(
        record_with_enrichment
      )
    end

    it 'returns none when known_exploited is false (filter not applied)' do
      expect(described_class.with_cve_enrichment_filters(known_exploited: false)).to be_empty
    end
  end

  context 'when filtering by epss_score' do
    it 'returns records with EPSS score greater than threshold' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :greater_than, epss_value: 0.5))
        .to contain_exactly(record_with_enrichment)
    end

    it 'returns records with EPSS score less than threshold' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :less_than, epss_value: 0.5))
        .to contain_exactly(record_with_enrichment_no_exploit)
    end

    it 'returns empty when no records match' do
      expect(described_class.with_cve_enrichment_filters(epss_operator: :greater_than, epss_value: 0.9)).to be_empty
    end
  end

  context 'when filtering by both known_exploited and epss_score' do
    it 'returns records matching both criteria' do
      expect(described_class.with_cve_enrichment_filters(
        known_exploited: true,
        epss_operator: :greater_than,
        epss_value: 0.5
      )).to contain_exactly(record_with_enrichment)
    end

    it 'filters by epss score only when known_exploited false' do
      expect(described_class.with_cve_enrichment_filters(
        known_exploited: false,
        epss_operator: :greater_than,
        epss_value: 0.2
      )).to contain_exactly(record_with_enrichment, record_with_enrichment_no_exploit)
    end
  end

  context 'when no filters are provided' do
    it 'returns none' do
      expect(described_class.with_cve_enrichment_filters).to eq(described_class.none)
    end
  end

  context 'when include_findings_without_enrichment_data is true' do
    let(:records_with_usable_enrichment) { [record_with_enrichment, record_with_enrichment_no_exploit] }
    let(:records_without_usable_enrichment) { described_class.all - records_with_usable_enrichment }

    context 'without any KEV/EPSS filter' do
      it 'returns none because fallback requires at least one enrichment filter' do
        expect(described_class.with_cve_enrichment_filters(include_findings_without_enrichment_data: true))
          .to eq(described_class.none)
      end
    end

    context 'when combined with known_exploited filter' do
      it 'returns matching enriched records and all records without usable enrichment data' do
        expect(described_class.with_cve_enrichment_filters(
          include_findings_without_enrichment_data: true,
          known_exploited: true
        )).to match_array([record_with_enrichment] + records_without_usable_enrichment)
      end
    end

    context 'when combined with epss_score filter' do
      it 'returns matching enriched records and all records without usable enrichment data' do
        expect(described_class.with_cve_enrichment_filters(
          include_findings_without_enrichment_data: true,
          epss_operator: :greater_than,
          epss_value: 0.5
        )).to match_array([record_with_enrichment] + records_without_usable_enrichment)
      end
    end
  end

  context 'when include_findings_without_enrichment_data is false' do
    it 'returns none when no other filters provided' do
      expect(described_class.with_cve_enrichment_filters(include_findings_without_enrichment_data: false))
        .to eq(described_class.none)
    end

    context 'when combined with other CVE filters' do
      it 'applies only the KEV/EPSS filters without fallback' do
        expect(described_class.with_cve_enrichment_filters(
          include_findings_without_enrichment_data: false,
          known_exploited: true
        )).to contain_exactly(record_with_enrichment)
      end
    end
  end
end
