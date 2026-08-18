# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreScanService, feature_category: :vulnerability_management do
  let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :sast) }

  let(:known_keys) { Set.new }

  before do
    artifact.job.update!(status: :success)
  end

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(artifact, known_keys, false) }

    before do
      allow(described_class).to receive(:new).with(artifact, known_keys, false,
        report: nil).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::StoreScanService`' do
      execute

      expect(described_class).to have_received(:new).with(artifact, known_keys, false, report: nil)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let_it_be(:unique_finding_uuid) { artifact.security_report.findings[0].uuid }
    let_it_be(:duplicate_finding_uuid) { artifact.security_report.findings[4].uuid }

    let(:finding_location_fingerprint) do
      build(
        :ci_reports_security_locations_sast,
        file_path: "groovy/src/main/java/com/gitlab/security_products/tests/App.groovy",
        start_line: "41",
        end_line: "41"
      ).fingerprint
    end

    let(:finding_identifier_fingerprint) do
      build(:ci_reports_security_identifier, external_id: "PREDICTABLE_RANDOM").fingerprint
    end

    let(:deduplicate) { false }
    let(:service_object) { described_class.new(artifact, known_keys, deduplicate) }
    let(:finding_key) do
      build(
        :ci_reports_security_finding_key,
        location_fingerprint: finding_location_fingerprint,
        identifier_fingerprint: finding_identifier_fingerprint
      )
    end

    subject(:store_scan) { service_object.execute }

    before do
      allow(Security::StoreFindingsService).to receive(:execute).and_return(status: :success)

      known_keys.add(finding_key)
    end

    it 'creates a succeeded security scan' do
      expect { store_scan }.to change { Security::Scan.succeeded.count }.by(1)
    end

    describe 'setting the `created_at` attribute of security scan', :freeze_time do
      let(:pipeline) { artifact.job.pipeline }

      before do
        allow(pipeline).to receive(:security_scans_created_at).and_return(1.day.ago)
      end

      it 'sets the `created_at` attribute of the new scan correctly' do
        store_scan

        expect(pipeline.security_scans.last.created_at).to eq(1.day.ago)
      end
    end

    describe 'setting the findings_partition_number' do
      let(:partition_number) { 222 }
      let(:pipeline) { artifact.job.pipeline }
      let(:scans_in_partition) { Security::Scan.where(findings_partition_number: partition_number) }

      before do
        allow(pipeline).to receive(:security_findings_partition_number).and_return(partition_number)
      end

      it 'sets the correct value' do
        expect { store_scan }.to change { scans_in_partition.count }.by(1)
      end
    end

    context 'when the `vulnerability_finding_signatures` licensed feature is available' do
      before do
        stub_licensed_features(vulnerability_finding_signatures: true)

        allow(Security::OverrideUuidsService).to receive(:execute)
      end

      it 'calls `Security::OverrideUuidsService` with security report to re-calculate the finding UUIDs' do
        store_scan

        expect(Security::OverrideUuidsService).to have_received(:execute).with(artifact.security_report)
      end
    end

    describe 'setting partial scan mode' do
      let(:security_scan) { Security::Scan.last }

      shared_examples 'stores partial scan record' do
        it 'stores the partial scan with correct attributes' do
          store_scan

          expect(security_scan.partial_scan_mode).to eq('differential')
          expect(security_scan.partial_scan).to have_attributes(
            mode: 'differential',
            pipeline: security_scan.pipeline,
            project: security_scan.project,
            scan_type: security_scan.scan_type
          )
        end
      end

      it 'does not create partial scan record' do
        store_scan

        expect(security_scan.partial_scan).to be_nil
      end

      context 'with differential scan' do
        let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :sast_differential_scan) }

        it_behaves_like 'stores partial scan record'

        context 'when there is an existing security scan' do
          let_it_be(:existing_scan) do
            create(:security_scan, build: artifact.job, scan_type: artifact.security_report.type)
          end

          it_behaves_like 'stores partial scan record'

          context 'when there is an existing partial scan' do
            let_it_be(:existing_partial_scan) do
              create(:vulnerabilities_partial_scan, scan: existing_scan)
            end

            it_behaves_like 'stores partial scan record'
          end
        end

        context 'when the report has some errors' do
          before do
            artifact.security_report.errors << { 'type' => 'foo', 'message' => 'bar' }
          end

          it_behaves_like 'stores partial scan record'
        end
      end

      context 'with cyclonedx artifact' do
        let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :cyclonedx) }

        it 'does not create partial scan record' do
          store_scan

          expect(security_scan.partial_scan).to be_nil
        end
      end
    end

    context 'when the `vulnerability_finding_signatures` licensed feature is not available' do
      before do
        stub_licensed_features(vulnerability_finding_signatures: false)

        allow(Security::OverrideUuidsService).to receive(:execute)
      end

      it 'does not call `Security::OverrideUuidsService`' do
        store_scan

        expect(Security::OverrideUuidsService).not_to have_received(:execute)
      end
    end

    context 'when the report has some errors' do
      before do
        artifact.security_report.errors << { 'type' => 'foo', 'message' => 'bar' }
      end

      it 'does not call the `Security::StoreFindingsService` and returns false' do
        expect(store_scan).to be(false)
        expect(Security::StoreFindingsService).not_to have_received(:execute)
      end

      it 'sets the status of the scan as `report_error`' do
        expect { store_scan }.to change { Security::Scan.report_error.count }.by(1)
      end
    end

    context 'when the report is produced by a failed job' do
      before do
        artifact.job.update!(status: :failed)
      end

      it 'does not call the `Security::StoreFindingsService` and sets the security scan as `job_failed`' do
        expect { store_scan }.to change { Security::Scan.job_failed.count }.by(1)

        expect(Security::StoreFindingsService).not_to have_received(:execute)
      end
    end

    context 'when the security report has an empty string scanner_external_id' do
      before do
        allow(artifact.security_report).to receive(:scanner_external_id).and_return('')
      end

      it 'stores nil in scanner_external_id on the scan record' do
        store_scan

        expect(Security::Scan.last.scanner_external_id).to be_nil
      end
    end

    context 'when the security report has no scanner information' do
      let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :sast_with_missing_scanner) }

      before do
        artifact.job.update!(status: :success)
      end

      it 'marks the scan as preparation_failed' do
        expect { store_scan }.to change { Security::Scan.preparation_failed.count }.by(1)

        expect(Security::StoreFindingsService).not_to have_received(:execute)

        security_scan = Security::Scan.last
        expect(security_scan.processing_errors).to include(
          hash_including(
            'type' => 'ScanIngestionError',
            'message' => 'Ingestion failed for security scan'
          )
        )
      end
    end

    context 'when storing the findings raises an error' do
      let(:error) { RuntimeError.new }
      let(:expected_errors) { [{ 'type' => 'ScanIngestionError', 'message' => 'Ingestion failed for security scan' }] }
      let!(:security_scan) { create(:security_scan, build: artifact.job, scan_type: artifact.file_type) }

      before do
        allow(Security::StoreFindingsService).to receive(:execute).and_raise(error)
        allow(Gitlab::ErrorTracking).to receive(:track_exception)
      end

      it 'marks the security scan as `preparation_failed` and tracks the error' do
        expect { store_scan }.to change { security_scan.reload.status }.to('preparation_failed')
                             .and change { security_scan.reload.processing_errors }.to(expected_errors)

        expect(Gitlab::ErrorTracking).to have_received(:track_exception).with(error)
      end
    end

    context 'when the report is produced by a retried job' do
      before do
        artifact.job.update!(retried: true)
      end

      it 'does not call the `Security::StoreFindingsService` and sets the security scan as non latest' do
        expect { store_scan }.to change { Security::Scan.where(latest: false).count }.by(1)

        expect(Security::StoreFindingsService).not_to have_received(:execute)
      end

      context 'with an existing scan' do
        let_it_be(:security_scan) do
          create(:security_scan, build: artifact.job, scan_type: :sast, status: :created)
        end

        it 'sets status to preparing' do
          expect { store_scan }.to change { security_scan.reload.status }.from('created').to('preparing')
        end

        context 'when scan was created after scan was initialized' do
          before do
            allow(Security::Scan).to receive(:find_or_initialize_by)
              .and_return(Security::Scan.new(build: artifact.job, scan_type: :sast), security_scan)
          end

          it 'sets status to preparing' do
            expect { store_scan }.to change { security_scan.reload.status }.from('created').to('preparing')
          end
        end
      end
    end

    context 'when the report does not have any errors' do
      before do
        artifact.security_report.errors.clear
      end

      describe 'executing `StoreFindingsService`' do
        let_it_be(:project) { artifact.project }
        let_it_be(:security_scanner) { artifact.security_report.scanner }

        context 'when there is already a vulnerability scanner' do
          let_it_be(:scanner) do
            create(:vulnerabilities_scanner, project: project, external_id: security_scanner.external_id)
          end

          it 'calls the `Security::StoreFindingsService` to store findings' do
            store_scan

            expect(Security::StoreFindingsService).to have_received(:execute).with(
              an_instance_of(Security::Scan), scanner, artifact.security_report, an_instance_of(Array))
          end

          it 'does not create a new scanner' do
            expect { store_scan }.not_to change { Vulnerabilities::Scanner.count }
          end
        end

        context 'when there is no vulnerability scanner' do
          it 'calls the `Security::StoreFindingsService` to store findings with the recently created scanner' do
            store_scan

            created_scanner = project.vulnerability_scanners.find_by(external_id: security_scanner.external_id)

            expect(Security::StoreFindingsService).to have_received(:execute).with(
              an_instance_of(Security::Scan), created_scanner, artifact.security_report, an_instance_of(Array))
          end

          it 'creates a new scanner' do
            expect { store_scan }.to change { Vulnerabilities::Scanner.count }.by(1)
          end
        end

        context 'when the report originates from a dependency scanning cyclonedx report' do
          let_it_be_with_refind(:artifact) { create(:ee_ci_job_artifact, :cyclonedx) }

          it 'stores a dependency_scanning scan' do
            expect { store_scan }.to change { artifact.job.security_scans.dependency_scanning.count }.by(1)
          end
        end
      end

      context 'when the report has no warnings' do
        before do
          artifact.security_report.warnings = []
        end

        let(:security_scan) { Security::Scan.last }

        it 'does not store an empty array' do
          store_scan

          expect(security_scan.info).to eq({})
        end
      end

      context 'when the report has some warnings' do
        before do
          artifact.security_report.warnings << { 'type' => 'foo', 'message' => 'bar' }
        end

        let(:security_scan) { Security::Scan.last }

        it 'calls the `Security::StoreFindingsService` to store findings' do
          expect(store_scan).to be(true)

          expect(Security::StoreFindingsService).to have_received(:execute)
        end

        it 'stores the warnings' do
          store_scan

          expect(security_scan.processing_warnings).to include(
            { 'type' => 'foo', 'message' => 'bar' }
          )
        end
      end

      context 'when the security scan already exists for the artifact' do
        let_it_be(:security_scan) do
          create(:security_scan, build: artifact.job, scan_type: :sast, status: :created)
        end

        let_it_be(:unique_security_finding) do
          create(:security_finding, scan: security_scan, uuid: unique_finding_uuid)
        end

        let_it_be(:duplicated_security_finding) do
          create(:security_finding, scan: security_scan, uuid: duplicate_finding_uuid)
        end

        it 'does not create a new security scan' do
          expect { store_scan }.not_to change { artifact.job.security_scans.count }
        end

        it 'changes the scan status' do
          expect { store_scan }.to change { security_scan.reload.status }.from('created').to('succeeded')
        end

        context 'when the `deduplicate` param is set as false' do
          it 'does not change the deduplicated flag of duplicated finding' do
            expect { store_scan }.not_to change { duplicated_security_finding.reload.deduplicated }.from(false)
          end

          it 'does not change the deduplicated flag of unique finding' do
            expect { store_scan }.not_to change { unique_security_finding.reload.deduplicated }.from(false)
          end
        end

        context 'when the `deduplicate` param is set as true' do
          let(:deduplicate) { true }

          context 'when the `StoreFindingsService` returns success' do
            it 'does not run the re-deduplicate logic' do
              expect { store_scan }.not_to change { unique_security_finding.reload.deduplicated }.from(false)
            end
          end

          context 'when the `StoreFindingsService` returns error' do
            before do
              allow(Security::StoreFindingsService).to receive(:execute).and_return({ status: :error })
            end

            it 'does not change the deduplicated flag of duplicated finding from false' do
              expect { store_scan }.not_to change { duplicated_security_finding.reload.deduplicated }.from(false)
            end

            it 'sets the deduplicated flag of unique finding as true' do
              expect { store_scan }.to change { unique_security_finding.reload.deduplicated }.to(true)
            end
          end
        end
      end

      context 'when the security scan does not exist for the artifact' do
        let(:unique_finding_attribute) do
          -> { Security::Finding.by_uuid(unique_finding_uuid).first&.deduplicated }
        end

        let(:duplicated_finding_attribute) do
          -> { Security::Finding.by_uuid(duplicate_finding_uuid).first&.deduplicated }
        end

        before do
          allow(Security::StoreFindingsService).to receive(:execute).and_call_original
        end

        it 'creates a new security scan' do
          expect { store_scan }.to change { artifact.job.security_scans.sast.count }.by(1)
        end

        context 'when the `deduplicate` param is set as false' do
          it 'sets the deduplicated flag of duplicated finding as false' do
            expect { store_scan }.to change { duplicated_finding_attribute.call }.to(false)
          end

          it 'sets the deduplicated flag of unique finding as true' do
            expect { store_scan }.to change { unique_finding_attribute.call }.to(true)
          end
        end

        context 'when the `deduplicate` param is set as true' do
          let(:deduplicate) { true }

          it 'sets the deduplicated flag of duplicated finding false' do
            expect { store_scan }.to change { duplicated_finding_attribute.call }.to(false)
          end

          it 'sets the deduplicated flag of unique finding as true' do
            expect { store_scan }.to change { unique_finding_attribute.call }.to(true)
          end
        end
      end
    end
  end
end
