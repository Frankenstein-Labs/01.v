# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::StoreGroupedSbomScansService, feature_category: :dependency_management do
  let_it_be(:report_type) { :dependency_scanning }
  let_it_be(:file_type) { :cyclonedx }
  let_it_be(:build_1) { create(:ee_ci_build) }
  let_it_be(:build_2) { create(:ee_ci_build) }
  let_it_be(:build_3) { create(:ee_ci_build) }
  let_it_be(:build_4) { create(:ee_ci_build) }
  let_it_be(:artifact_1) { create(:ee_ci_job_artifact, file_type, job: build_1) }
  let_it_be(:artifact_2) { create(:ee_ci_job_artifact, file_type, job: build_2) }
  let_it_be(:artifact_3) { create(:ee_ci_job_artifact, file_type, job: build_3) }
  let_it_be(:pipeline) { artifact_1.job.pipeline }
  let_it_be(:pipeline_id) { pipeline.id }

  let(:artifacts) { [artifact_1, artifact_2, artifact_3] }

  describe '.execute' do
    let(:mock_service_object) { instance_double(described_class, execute: true) }

    subject(:execute) { described_class.execute(artifacts, pipeline, report_type) }

    before do
      allow(described_class).to receive(:new).with(artifacts, pipeline, report_type).and_return(mock_service_object)
    end

    it 'delegates the call to an instance of `Security::StoreGroupedScansService`' do
      execute

      expect(described_class).to have_received(:new).with(artifacts, pipeline, report_type)
      expect(mock_service_object).to have_received(:execute)
    end
  end

  describe '#execute' do
    let(:service_object) { described_class.new(artifacts, pipeline, report_type) }
    let(:mock_report_1) do
      instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: 1, scan: nil)
    end

    let(:mock_report_2) do
      instance_double(::Gitlab::Ci::Reports::Security::Report, scanner_order_to: -1, scan: nil)
    end

    let(:mock_report_3) { instance_double(::Gitlab::Ci::Reports::Security::Report, scan: nil) }
    let(:artifacts) { [artifact_1, artifact_2, artifact_3] }
    let(:empty_set) { Set.new }

    subject(:store_scan_group) { service_object.execute }

    before do
      allow(Security::StoreSbomScanService).to receive(:execute).and_return(true)
      allow(artifact_1).to receive(:security_report).and_return(mock_report_1)
      allow(artifact_2).to receive(:security_report).and_return(mock_report_2)
      allow(artifact_3).to receive(:security_report).and_return(mock_report_3)
      allow(artifact_1).to receive(:clear_security_report)
      allow(artifact_2).to receive(:clear_security_report)
      allow(artifact_3).to receive(:clear_security_report)
    end

    it 'calls the Security::StoreSbomScanService with ordered artifacts' do
      store_scan_group

      expect(Security::StoreSbomScanService).to have_received(:execute).with(artifact_2, empty_set, false).ordered
      expect(Security::StoreSbomScanService).to have_received(:execute).with(artifact_3, empty_set, true).ordered
      expect(Security::StoreSbomScanService).to have_received(:execute).with(artifact_1, empty_set, true).ordered
    end

    it 'calls clear security report to each artifact' do
      store_scan_group

      expect(artifact_2).to have_received(:clear_security_report)
      expect(artifact_3).to have_received(:clear_security_report)
      expect(artifact_1).to have_received(:clear_security_report)
    end
  end
end
