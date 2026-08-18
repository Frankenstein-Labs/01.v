# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreFindingsService, feature_category: :vulnerability_management do
  let_it_be(:findings_partition_number) { Security::Finding.active_partition_number }
  let_it_be(:security_scan) { create(:security_scan, findings_partition_number: findings_partition_number) }
  let_it_be(:project) { security_scan.project }
  let_it_be(:scanner) { create(:vulnerabilities_scanner, project: project) }
  let_it_be(:security_finding_1) { build(:ci_reports_security_finding) }
  let_it_be(:security_finding_2) { build(:ci_reports_security_finding) }
  let_it_be(:security_finding_3) { build(:ci_reports_security_finding) }
  let_it_be_with_reload(:security_finding_4) { build(:ci_reports_security_finding) }
  let_it_be(:deduplicated_finding_uuids) { [security_finding_1.uuid, security_finding_3.uuid] }
  let_it_be(:security_scanner) { build(:ci_reports_security_scanner) }
  let_it_be(:report) do
    build(
      :ci_reports_security_report,
      findings: [security_finding_1, security_finding_2, security_finding_3, security_finding_4],
      scanner: security_scanner
    )
  end

  describe '#execute' do
    let(:service_object) { described_class.new(security_scan, scanner, report, deduplicated_finding_uuids) }

    subject(:store_findings) { service_object.execute }

    context 'when the given security scan already has findings' do
      before do
        create(:security_finding, scan: security_scan)
        security_finding_4.uuid = nil
      end

      it 'returns error message' do
        expect(store_findings).to eq({ status: :error, message: "Findings are already stored!" })
      end

      it 'does not create new findings in database' do
        expect { store_findings }.not_to change { Security::Finding.count }
      end
    end

    context 'when the given security scan does not have any findings' do
      before do
        security_scan.findings.delete_all
      end

      it 'creates the security finding entries in database' do
        store_findings

        checked_fields = [:partition_number, :uuid, :context_unaware_uuid, :deduplicated]

        expect(security_scan.findings.reload.as_json(only: checked_fields))
          .to match_array(
            [
              {
                "partition_number" => findings_partition_number,
                "uuid" => security_finding_1.uuid,
                "context_unaware_uuid" => security_finding_1.context_unaware_uuid,
                "deduplicated" => true
              },
              {
                "partition_number" => findings_partition_number,
                "uuid" => security_finding_2.uuid,
                "context_unaware_uuid" => security_finding_2.context_unaware_uuid,
                "deduplicated" => false
              },
              {
                "partition_number" => findings_partition_number,
                "uuid" => security_finding_3.uuid,
                "context_unaware_uuid" => security_finding_3.context_unaware_uuid,
                "deduplicated" => true
              }
            ])
      end

      it 'stores raw_source_code_extract from original_data in database' do
        store_findings

        expect(security_scan.findings.reload.as_json(only: :finding_data)).to include(
          a_hash_including(
            "finding_data" => a_hash_including("raw_source_code_extract" => security_finding_1.raw_source_code_extract)
          ),
          a_hash_including(
            "finding_data" => a_hash_including("raw_source_code_extract" => security_finding_2.raw_source_code_extract)
          ),
          a_hash_including(
            "finding_data" => a_hash_including("raw_source_code_extract" => security_finding_3.raw_source_code_extract)
          )
        )
      end

      context 'when findings have CVE identifiers' do
        let_it_be(:cve_identifier_1) do
          build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-1234')
        end

        let_it_be(:cve_identifier_2) do
          build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-5678')
        end

        let_it_be(:cve_identifier_3) do
          build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-8910')
        end

        let_it_be(:cve_identifier_4) do
          build(:ci_reports_security_identifier, external_type: 'cve', name: 'CVE-2024-9999')
        end

        let_it_be(:non_cve_identifier) { build(:ci_reports_security_identifier, external_type: 'cwe', name: 'CWE-79') }

        let_it_be(:finding_with_single_cve) do
          build(:ci_reports_security_finding, identifiers: [cve_identifier_1, non_cve_identifier])
        end

        let_it_be(:finding_with_multiple_cves) do
          build(:ci_reports_security_finding, identifiers: [cve_identifier_2, cve_identifier_3])
        end

        let_it_be(:finding_without_cve) do
          build(:ci_reports_security_finding, identifiers: [non_cve_identifier])
        end

        let_it_be(:finding_with_unenriched_cve) do
          build(:ci_reports_security_finding, identifiers: [cve_identifier_4])
        end

        let_it_be(:report_with_cves) do
          build(
            :ci_reports_security_report,
            findings: [
              finding_with_single_cve,
              finding_with_multiple_cves,
              finding_without_cve,
              finding_with_unenriched_cve
            ],
            scanner: security_scanner
          )
        end

        let(:deduplicated_finding_uuids) { [] }
        let(:execute_service) { store_findings }

        let(:create_security_finding_for_cve_identifier_1) do
          create(:security_finding, uuid: finding_with_single_cve.uuid)
        end

        let(:service_object) do
          described_class.new(security_scan, scanner, report_with_cves, deduplicated_finding_uuids)
        end

        it_behaves_like 'a service that syncs finding enrichments'

        it 'associates enrichments with security findings' do
          store_findings

          finding_2 = Security::Finding.find_by(uuid: finding_with_multiple_cves.uuid)

          expect(finding_2.finding_enrichments.pluck(:cve)).to contain_exactly('CVE-2024-5678', 'CVE-2024-8910')
        end

        it 'does not create enrichments for non-CVE identifiers' do
          store_findings

          db_finding = Security::Finding.find_by(uuid: finding_without_cve.uuid)
          expect(db_finding.finding_enrichments).to be_empty
        end

        it 'does not set vulnerability_id on enrichments for CI report findings' do
          store_findings

          enrichments = Security::FindingEnrichment.where(project: project)
          expect(enrichments.pluck(:vulnerability_id)).to all(be_nil)
        end

        context 'when enrichment population fails' do
          before do
            allow(Security::FindingEnrichment).to receive(:upsert_all).and_raise(StandardError.new('Database error'))
          end

          it 'tracks the exception with scan context' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              an_instance_of(StandardError),
              hash_including(
                security_scan_id: security_scan.id,
                project_id: project.id,
                class: 'Security::StoreFindingsService'
              )
            )

            store_findings
          end

          it 'still creates the security findings' do
            expect { store_findings }.to change { Security::Finding.count }.by(4)
          end
        end
      end

      context 'when severity overrides are applied' do
        let_it_be(:vulnerability) { create(:vulnerability, :critical_severity, project: project) }
        let_it_be(:vulnerability_finding) do
          create(:vulnerabilities_finding,
            vulnerability: vulnerability,
            project: project,
            uuid: security_finding_1.uuid,
            severity: :critical)
        end

        let_it_be_with_reload(:severity_override) do
          create(:vulnerability_severity_override,
            vulnerability: vulnerability,
            original_severity: :high,
            new_severity: :critical)
        end

        before do
          security_scan.findings.delete_all
        end

        it 'stores scanner_reported_severity for all findings' do
          store_findings

          findings = security_scan.findings.reload
          expect(findings.pluck(:scanner_reported_severity)).to all(be_present)
        end

        it 'uses overridden severity when a severity override exists' do
          store_findings

          finding = security_scan.findings.find_by(uuid: security_finding_1.uuid)
          expect(finding.severity).to eq('critical')
          expect(finding.scanner_reported_severity).to eq(security_finding_1.severity.to_s)
        end

        it 'uses scanner severity when no override exists' do
          store_findings

          finding = security_scan.findings.find_by(uuid: security_finding_2.uuid)
          expect(finding.severity).to eq(security_finding_2.severity.to_s)
          expect(finding.scanner_reported_severity).to eq(security_finding_2.severity.to_s)
        end

        context 'when batch has no findings with UUIDs' do
          it 'returns empty hash from lookup_severity_overrides for empty input' do
            result = service_object.send(:lookup_severity_overrides, [])
            expect(result).to eq({})
          end
        end
      end

      context 'when findings have no identifiers' do
        let_it_be(:security_finding_no_identifiers) do
          build(:ci_reports_security_finding, identifiers: [])
        end

        let_it_be(:report_no_identifiers) do
          build(
            :ci_reports_security_report,
            findings: [security_finding_no_identifiers],
            scanner: security_scanner
          )
        end

        let(:service_object) do
          described_class.new(security_scan, scanner, report_no_identifiers, [])
        end

        it 'does not create security finding entries for invalid findings' do
          expect { store_findings }.not_to change { Security::Finding.count }
        end

        it 'does not create finding enrichment records' do
          expect { store_findings }.not_to change { Security::FindingEnrichment.count }
        end
      end
    end
  end
end
