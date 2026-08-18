# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreSbomScanService, feature_category: :dependency_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user, ref: project.default_branch, project: project) }
  let_it_be(:build) { create(:ee_ci_build, :success, pipeline: pipeline) }
  let_it_be(:report_type) { :dependency_scanning }
  let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :cyclonedx, job: build) }

  let(:known_keys) { Set.new }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(artifact, known_keys, false) }

    before do
      allow(described_class).to receive(:new).with(artifact, known_keys, false,
        report: nil).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::StoreSbomScanService`' do
      execute

      expect(described_class).to have_received(:new).with(artifact, known_keys, false, report: nil)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:deduplicate) { false }
    let(:service_object) { described_class.new(artifact, known_keys, deduplicate) }
    let_it_be(:affected_package) do
      create(:pm_affected_package, purl_type: :npm, package_name: 'yargs-parser', affected_range: "<9.1")
    end

    let_it_be(:affected_package_2) do
      create(:pm_affected_package, purl_type: :npm, package_name: 'yargs-parser', affected_range: "<9.5")
    end

    let_it_be(:report_findings) { artifact.security_report.findings }
    let_it_be(:finding_uuids) { report_findings.map(&:uuid) }

    subject(:store_scan) { service_object.execute }

    before do
      allow(Gitlab::ErrorTracking).to receive(:track_exception)
    end

    context 'when storing the findings raises an error' do
      let(:error) { RuntimeError.new }
      let(:expected_errors) { [{ 'type' => 'ScanIngestionError', 'message' => 'Ingestion failed for security scan' }] }
      let_it_be(:security_scan) { create(:security_scan, build: artifact.job, scan_type: report_type) }

      before do
        allow(Security::StoreSbomFindingsService).to receive(:execute).and_raise(error)
      end

      it 'marks the security scan as `preparation_failed` and tracks the error' do
        expect { store_scan }.to change { security_scan.reload.status }.to('preparation_failed')
                             .and change { security_scan.reload.processing_errors }.to(expected_errors)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
      end
    end

    context 'when the report does not have any errors' do
      it 'creates two security finding records' do
        expect { store_scan }.to change { Security::Finding.count }.by(finding_uuids.count)
      end

      it 'marks the security scan as `succeeded`' do
        store_scan

        expect(Gitlab::ErrorTracking).not_to have_received(:track_exception)
        expect(Security::Scan.last.succeeded?).to be true
      end

      context 'with existing security findings' do
        let_it_be(:security_scan) { create(:security_scan, build: artifact.job, scan_type: report_type) }
        let_it_be(:finding) { create(:security_finding, scan: security_scan, uuid: finding_uuids[0]) }

        it 'creates a security finding based on the non-existing finding' do
          expect { store_scan }.to change { Security::Finding.count }.by(finding_uuids.count - 1)
        end
      end
    end
  end
end
