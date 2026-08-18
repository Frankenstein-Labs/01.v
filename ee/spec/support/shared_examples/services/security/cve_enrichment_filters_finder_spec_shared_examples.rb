# frozen_string_literal: true

RSpec.shared_examples 'CVE enrichment filters finder spec' do
  context 'when applying all CVE enrichment filters' do
    let(:filter_params) do
      {
        enrichment_data_unavailable_action: 'block',
        known_exploited: true,
        epss_score: { operator: :greater_than, value: 0.5 }
      }
    end

    it 'returns enrichment-matched records and all records without usable enrichment data' do
      records_without_usable_enrichment = all_records.reject do |r|
        [finding_with_enrichment, finding_with_enrichment_no_exploit].include?(r)
      end

      is_expected.to match_array([finding_with_enrichment] + records_without_usable_enrichment)
    end

    it 'calls with_cve_enrichment_filters with correct parameters' do
      expect(model_class).to receive(:with_cve_enrichment_filters).with(
        known_exploited: true,
        epss_operator: :greater_than,
        epss_value: 0.5,
        include_findings_without_enrichment_data: true
      ).and_call_original

      subject
    end
  end

  context 'when filtering by known_exploited' do
    context 'when known_exploited is true' do
      let(:filter_params) { { known_exploited: true } }

      it { is_expected.to contain_exactly(finding_with_enrichment) }
    end

    context 'when known_exploited is false' do
      let(:filter_params) { { known_exploited: false } }

      it { is_expected.to match_array(all_records) }
    end
  end

  context 'when filtering by epss_score' do
    {
      greater_than: [0.5, [:finding_with_enrichment]],
      less_than: [0.9, %i[finding_with_enrichment finding_with_enrichment_no_exploit]]
    }.each do |operator, (value, expected)|
      context operator.to_s do
        let(:filter_params) { { epss_score: { operator: operator, value: value } } }

        it { is_expected.to match_array(expected.map { |f| send(f) }) }
      end
    end
  end

  context 'when combining known_exploited and epss_score' do
    let(:filter_params) do
      {
        known_exploited: true,
        epss_score: { operator: :greater_than, value: 0.5 }
      }
    end

    it { is_expected.to contain_exactly(finding_with_enrichment) }
  end

  context 'when no records match' do
    let(:filter_params) { { epss_score: { operator: :greater_than, value: 0.9 } } }

    it { is_expected.to be_empty }
  end

  context 'when filters are invalid' do
    let(:filter_params) do
      { epss_score: { operator: :invalid_operator, value: 'not_a_number' } }
    end

    it { is_expected.to match_array(all_records) }
  end

  context 'when enrichment_data_unavailable_action is block' do
    context 'without any KEV/EPSS filter' do
      let(:filter_params) { { enrichment_data_unavailable_action: 'block' } }

      it 'does not apply enrichment filters and returns all records' do
        is_expected.to match_array(all_records)
      end
    end

    context 'with a KEV/EPSS filter' do
      let(:filter_params) do
        {
          enrichment_data_unavailable_action: 'block',
          known_exploited: true
        }
      end

      it 'returns enrichment-matched records and all records without usable enrichment data' do
        records_without_usable_enrichment = all_records.reject do |r|
          [finding_with_enrichment, finding_with_enrichment_no_exploit].include?(r)
        end

        is_expected.to match_array([finding_with_enrichment] + records_without_usable_enrichment)
      end
    end
  end

  context 'when enrichment_data_unavailable_action is ignore' do
    let(:filter_params) do
      {
        enrichment_data_unavailable_action: 'ignore',
        known_exploited: true
      }
    end

    it 'applies only KEV/EPSS filters without fallback' do
      is_expected.to contain_exactly(finding_with_enrichment)
    end
  end
end
