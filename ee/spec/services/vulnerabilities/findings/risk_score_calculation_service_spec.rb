# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::Findings::RiskScoreCalculationService, feature_category: :vulnerability_management do
  subject(:service) { described_class.new(vulnerability_ids) }

  let_it_be(:project) { create(:project) }
  let_it_be(:vulnerability_ids) { [] }

  describe '#execute' do
    context "when vulnerabilities exist" do
      let_it_be(:vulnerability_list) { create_list(:vulnerability, 2, project: project) }

      let_it_be(:identifier_1) do
        create(:vulnerabilities_identifier, external_type: 'cve', external_id: 'CVE-2023-12345',
          name: 'CVE-2023-12345')
      end

      let_it_be(:identifier_2) do
        create(:vulnerabilities_identifier, external_type: 'cve', external_id: 'CVE-2021-12345',
          name: 'CVE-2021-12345')
      end

      let_it_be(:findings_list) do
        [
          create(:vulnerabilities_finding, vulnerability: vulnerability_list[0], project: project,
            identifiers: [identifier_1]),
          create(:vulnerabilities_finding, vulnerability: vulnerability_list[1], project: project,
            identifiers: [identifier_2])
        ]
      end

      let_it_be(:cve_enrichment_1) { create(:pm_cve_enrichment, cve: identifier_1.name, epss_score: 0.5) }
      let_it_be(:cve_enrichment_2) do
        create(:pm_cve_enrichment, cve: identifier_2.name, epss_score: 0.0, is_known_exploit: true)
      end

      let(:vulnerability_ids) { vulnerability_list.map(&:id) }

      it "updates the corresponding risk scores" do
        risk_scores = findings_list.map do |finding|
          {
            finding_id: finding.id,
            project_id: finding.project_id,
            risk_score: Vulnerabilities::RiskScore.from_finding(finding).score
          }
        end

        expect(Vulnerabilities::FindingRiskScore).to receive(:upsert_all)
          .with(risk_scores, unique_by: :finding_id, update_only: [:risk_score])

        service.execute
      end

      it "preloads cve_enrichment and does not make n+1 queries to the database" do
        control = ActiveRecord::QueryRecorder.new do
          service.execute
        end

        new_vulnerabilities = create_list(:vulnerability, 2, project: project)
        identifier_3 = create(:vulnerabilities_identifier, external_type: 'cve', external_id: 'CVE-2023-1234',
          name: 'CVE-2023-1234')
        identifier_4 = create(:vulnerabilities_identifier, external_type: 'cve', external_id: 'CVE-2021-1234',
          name: 'CVE-2021-1234')
        create(:vulnerabilities_finding, vulnerability: new_vulnerabilities[0], project: project,
          identifiers: [identifier_3])
        create(:vulnerabilities_finding, vulnerability: new_vulnerabilities[1], project: project,
          identifiers: [identifier_4])
        create(:pm_cve_enrichment, cve: identifier_3.name, epss_score: 0.5)
        create(:pm_cve_enrichment, cve: identifier_4.name, epss_score: 0.0, is_known_exploit: true)

        vulnerability_ids = vulnerability_list.map(&:id) + new_vulnerabilities.map(&:id)

        expect do
          described_class.new(vulnerability_ids).execute
        end.to issue_same_number_of_queries_as(control).allow_skip_cache_inconsistency
      end

      it 'logs changes for updated findings' do
        expect(Gitlab::AppLogger).to receive(:info)
          .with(
            class: described_class.name,
            message: "Vulnerability finding risk scores updated",
            vulnerability_ids: vulnerability_ids,
            timestamp: anything
          )

        service.execute
      end

      it "syncs to elasticsearch" do
        expect(Vulnerabilities::EsHelper).to receive(:sync_elasticsearch)
          .with(vulnerability_ids)

        service.execute
      end
    end
  end
end
