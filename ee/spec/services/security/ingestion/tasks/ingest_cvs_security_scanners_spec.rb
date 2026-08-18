# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestCvsSecurityScanners, feature_category: :software_composition_analysis do
  describe '#execute' do
    let(:pipeline_1) { create(:ci_pipeline) }
    let(:report_finding_1) { create(:ci_reports_security_finding) }
    let(:finding_map_1) { create(:vs_finding_map, pipeline: pipeline_1, report_finding: report_finding_1) }

    let(:pipeline_2) { create(:ci_pipeline) }
    let(:report_finding_2) { create(:ci_reports_security_finding) }
    let(:finding_map_2) { create(:vs_finding_map, pipeline: pipeline_2, report_finding: report_finding_2) }

    subject(:task) { described_class.new(nil, [finding_map_1, finding_map_2]) }

    context 'with no existing scanners' do
      it 'creates new scanners' do
        task.execute

        expect(Vulnerabilities::Scanner.count).to be(2)
        expect(Vulnerabilities::Scanner.all).to match_array([
          have_attributes(project_id: pipeline_1.project.id,
            external_id: Gitlab::VulnerabilityScanning::SecurityScanner::EXTERNAL_ID,
            name: Gitlab::VulnerabilityScanning::SecurityScanner::NAME,
            vendor: Gitlab::VulnerabilityScanning::SecurityScanner::VENDOR
          ),
          have_attributes(project_id: pipeline_2.project.id,
            external_id: Gitlab::VulnerabilityScanning::SecurityScanner::EXTERNAL_ID,
            name: Gitlab::VulnerabilityScanning::SecurityScanner::NAME,
            vendor: Gitlab::VulnerabilityScanning::SecurityScanner::VENDOR
          )
        ])
      end
    end

    context 'with existing scanner' do
      before do
        create(:vulnerabilities_scanner, project: pipeline_1.project,
          external_id: Gitlab::VulnerabilityScanning::SecurityScanner::EXTERNAL_ID,
          name: Gitlab::VulnerabilityScanning::SecurityScanner::NAME,
          vendor: Gitlab::VulnerabilityScanning::SecurityScanner::VENDOR
        )

        create(:vulnerabilities_scanner, project: pipeline_2.project,
          external_id: Gitlab::VulnerabilityScanning::SecurityScanner::EXTERNAL_ID,
          name: Gitlab::VulnerabilityScanning::SecurityScanner::NAME,
          vendor: Gitlab::VulnerabilityScanning::SecurityScanner::VENDOR
        )
      end

      it 'uses existing scanners' do
        expect { task.execute }.to not_change { Vulnerabilities::Scanner.count }
      end

      it 'does not attempt to upsert scanners' do
        travel_to(1.day.from_now) do
          expect { task.execute }.not_to change { Vulnerabilities::Scanner.first.updated_at }
        end
      end
    end

    context 'with duplicate maps' do
      let(:finding_map_2) { create(:vs_finding_map, pipeline: pipeline_1, report_finding: report_finding_2) }

      it 'sets scanner id for all maps' do
        expect { task.execute }.to change { Vulnerabilities::Scanner.count }.by(1)

        scanner_id = Vulnerabilities::Scanner.first.id
        expect(finding_map_1.scanner_id).to eq(scanner_id)
        expect(finding_map_2.scanner_id).to eq(scanner_id)
      end
    end
  end
end
