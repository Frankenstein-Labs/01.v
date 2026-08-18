# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestRemediations, feature_category: :vulnerability_management do
  describe '#execute' do
    let(:pipeline) { create(:ci_pipeline) }
    let(:existing_diff) { 'foo' }
    let(:new_diff) { 'bar' }
    let(:project) { pipeline.project }

    let(:existing_checksum) { Digest::SHA256.hexdigest(existing_diff) }
    let(:existing_remediation_1) { create(:vulnerabilities_remediation, project: project, checksum: existing_checksum, file: Tempfile.new.tap { _1.write(existing_diff) }, summary: 'Foo Summary') }
    let(:existing_remediation_2) { create(:vulnerabilities_remediation, project: project) }

    let(:vulnerability_1) { create(:vulnerability, project: project) }
    let(:vulnerability_2) { create(:vulnerability, project: project) }

    let(:vulnerability_read_1) { Vulnerabilities::Read.where(vulnerability_id: vulnerability_1).first }
    let(:vulnerability_read_2) { Vulnerabilities::Read.where(vulnerability_id: vulnerability_2).first }

    let(:report_remediation_1) { create(:ci_reports_security_remediation, diff: existing_diff, summary: "Foo Summary") }
    let(:report_remediation_2) { create(:ci_reports_security_remediation, diff: new_diff, summary: "Bar Summary") }

    let(:finding_1) { create(:vulnerabilities_finding, vulnerability: vulnerability_1, remediations: [existing_remediation_1, existing_remediation_2]) }
    let(:finding_2) { create(:vulnerabilities_finding, vulnerability: vulnerability_2) }

    let(:report_finding_1) { create(:ci_reports_security_finding, remediations: [report_remediation_1, report_remediation_2]) }
    let(:report_finding_2) { create(:ci_reports_security_finding, remediations: [report_remediation_1, report_remediation_2]) }

    let(:finding_map_1) { create(:finding_map, finding: finding_1, report_finding: report_finding_1) }
    let(:finding_map_2) { create(:finding_map, finding: finding_2, report_finding: report_finding_2) }

    let!(:service_object) { described_class.new(pipeline, [finding_map_1, finding_map_2]) }

    subject(:ingest_finding_remediations) do
      SecApplicationRecord.transaction do
        service_object.execute
      end
    end

    it_behaves_like 'bulk insertable task'

    it 'creates remediations and updates the associations' do
      expect { ingest_finding_remediations }.to change { Vulnerabilities::Remediation.count }.by(1)
                                            .and change { existing_remediation_2.reload.findings }.from([finding_1]).to([])
                                            .and change { finding_2.reload.association(:remediations).scope.count }.from(0).to(2)
                                            .and not_change { finding_1.reload.association(:remediations).scope.count }.from(2)
    end

    context 'when a new pipeline is run' do
      before do
        vulnerability_read_1.update!(has_remediations: true)
      end

      context 'when associated remediations for findings is changed' do
        let(:report_finding_with_no_remediation) { create(:ci_reports_security_finding, remediations: []) }
        let(:finding_map_1) { create(:finding_map, finding: finding_1, report_finding: report_finding_with_no_remediation) }

        it 'updates vulnerability reads' do
          expect { ingest_finding_remediations }.to change { vulnerability_read_1.reload.has_remediations }.from(true).to(false)
                                                .and change { vulnerability_read_2.reload.has_remediations }.from(false).to(true)
        end
      end

      context 'when associated remediations for findings is unchanged' do
        it 'do not update vulnerability reads' do
          expect { ingest_finding_remediations }.to not_change { vulnerability_read_1.reload.has_remediations }
        end
      end
    end

    it_behaves_like 'sync vulnerabilities changes to ES' do
      let(:expected_vulnerabilities) { [vulnerability_read_1, vulnerability_read_2] }

      subject do
        SecApplicationRecord.transaction do
          ingest_finding_remediations
        end
      end
    end

    it 'enqueues UploadRemediationsWorker with new remediation diffs' do
      new_checksum = Digest::SHA256.hexdigest(new_diff)

      ingest_finding_remediations

      new_remediation = Vulnerabilities::Remediation.find_by(checksum: new_checksum)
      expect(Vulnerabilities::UploadRemediationsWorker.jobs.size).to eq(1)
      expect(Vulnerabilities::UploadRemediationsWorker.jobs.first['args'].first).to include(
        new_remediation.id.to_s => new_diff
      )
    end

    context 'when all remediations already exist' do
      let(:report_remediation_2) { create(:ci_reports_security_remediation, diff: existing_diff, summary: "Foo Summary") }

      it 'does not enqueue UploadRemediationsWorker' do
        ingest_finding_remediations

        expect(Vulnerabilities::UploadRemediationsWorker.jobs).to be_empty
      end
    end
  end
end
