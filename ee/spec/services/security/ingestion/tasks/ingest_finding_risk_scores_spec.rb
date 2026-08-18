# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestFindingRiskScores, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:pipeline) { create(:ci_pipeline) }
    let_it_be_with_refind(:project) { pipeline.project }

    let_it_be(:security_identifier_critical) do
      create(:ci_reports_security_identifier, external_id: 'CVE-2023-12345', name: 'CVE-2023-12345',
        external_type: 'cve')
    end

    let_it_be(:security_identifier_medium) do
      create(:ci_reports_security_identifier, external_id: 'CVE-2023-67890', name: 'CVE-2023-67890',
        external_type: 'cve')
    end

    let_it_be(:cve_enrichment_critical) do
      create(:pm_cve_enrichment, cve: security_identifier_critical.name, epss_score: 0.9, is_known_exploit: true)
    end

    let_it_be(:cve_enrichment_medium) do
      create(:pm_cve_enrichment, cve: security_identifier_medium.name, epss_score: 0.4, is_known_exploit: false)
    end

    let_it_be(:security_finding_critical) { create(:security_finding, severity: :critical) }
    let_it_be(:security_finding_medium) { create(:security_finding, severity: :medium) }

    let_it_be(:report_finding_critical) do
      create(:ci_reports_security_finding, identifiers: [security_identifier_critical])
    end

    let_it_be(:report_finding_medium) do
      create(:ci_reports_security_finding, identifiers: [security_identifier_medium])
    end

    let_it_be(:finding_map_critical) do
      create(:finding_map, :new_record, security_finding: security_finding_critical,
        report_finding: report_finding_critical, pipeline: pipeline)
    end

    let_it_be(:finding_map_medium) do
      create(:finding_map, :new_record, security_finding: security_finding_medium,
        report_finding: report_finding_medium, pipeline: pipeline)
    end

    let_it_be(:low_vulnerability) { create(:vulnerability, :with_finding, severity: :low) }

    let_it_be(:finding_map_low) do
      create(:finding_map,
        finding: low_vulnerability.finding,
        vulnerability: low_vulnerability
      )
    end

    let_it_be(:finding_risk_score) do
      create(:vulnerability_finding_risk_score, finding: low_vulnerability.finding)
    end

    let(:finding_maps) { [finding_map_critical, finding_map_medium, finding_map_low] }

    subject(:ingest_risk_scores) { described_class.new(pipeline, finding_maps).execute }

    it "creates risk scores for all vulnerabilities" do
      expected_scores = {
        finding_map_critical.finding_id => Vulnerabilities::RiskScore.new(
          severity: finding_map_critical.severity,
          epss_score: cve_enrichment_critical.epss_score,
          is_known_exploit: cve_enrichment_critical.is_known_exploit
        ).score,
        finding_map_medium.finding_id => Vulnerabilities::RiskScore.new(
          severity: finding_map_medium.severity,
          epss_score: cve_enrichment_medium.epss_score,
          is_known_exploit: cve_enrichment_medium.is_known_exploit
        ).score,
        finding_map_low.finding_id => Vulnerabilities::RiskScore.new(
          severity: finding_map_low.severity,
          epss_score: 0.0,
          is_known_exploit: false
        ).score
      }

      expect { ingest_risk_scores }.to change { Vulnerabilities::FindingRiskScore.count }.by(2)

      expected_scores.each do |finding_id, expected_risk_score|
        finding_risk_score = Vulnerabilities::FindingRiskScore.find_by(finding_id: finding_id)
        expect(finding_risk_score.risk_score).to eq(expected_risk_score)
      end
    end

    describe 'N+1 queries' do
      it 'does not cause N+1 queries when processing multiple findings' do
        single_finding_map = create(:finding_map, :new_record, security_finding: security_finding_critical,
          report_finding: report_finding_critical, pipeline: pipeline)
        single_ingestion = described_class.new(pipeline, [single_finding_map])

        control = ActiveRecord::QueryRecorder.new { single_ingestion.execute }

        # Create additional report findings with CVE enrichments
        additional_report_findings = []
        2.times do |index|
          external_id = "CVE-2023-#{11111 + index}"
          security_identifier = create(:ci_reports_security_identifier, external_id: external_id, name: external_id,
            external_type: 'cve')
          create(:pm_cve_enrichment, cve: security_identifier.name, epss_score: 0.5 + (index * 0.1),
            is_known_exploit: false)
          report_finding = create(:ci_reports_security_finding, identifiers: [security_identifier])
          additional_report_findings << report_finding
        end

        additional_security_findings = create_list(:security_finding, 2)

        additional_finding_maps =
          additional_security_findings.zip(additional_report_findings).map do |security_finding, report_finding|
            create(:finding_map, :new_record, security_finding: security_finding,
              report_finding: report_finding, pipeline: pipeline)
          end

        all_finding_maps = [single_finding_map] + additional_finding_maps
        multi_ingestion = described_class.new(pipeline, all_finding_maps)

        expect { multi_ingestion.execute }.not_to exceed_query_limit(control)
      end
    end
  end
end
