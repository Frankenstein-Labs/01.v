# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::ExecutionStrategy::ContainerScanningForRegistry, feature_category: :dependency_management do
  let_it_be(:pipeline) { build_stubbed(:ci_pipeline) }
  let_it_be(:project) { pipeline.project }
  let_it_be(:reports) { create_list(:ci_reports_sbom_report, 3) }

  let(:report_ingested_ids) { [[10], [20], [30]] }
  let(:ingested_source_ids) { [1] }
  let(:ingested_ids) { report_ingested_ids.flatten }

  subject(:strategy) { described_class.new(reports, project, pipeline) }

  describe '#execute' do
    before do
      reports.zip(report_ingested_ids) do |report, ingested_ids|
        allow(Sbom::Ingestion::IngestReportService)
          .to receive(:execute).with(pipeline, report)
          .and_return({ occurrence_ids: ingested_ids, source_ids: ingested_source_ids })
      end

      allow(Gitlab::EventStore).to receive(:publish)
      allow(Sbom::Ingestion::ContainerScanningForRegistry::DeleteNotPresentOccurrencesService).to receive(:execute)
    end

    it 'ingests the reports' do
      strategy.execute

      reports.each do |report|
        expect(Sbom::Ingestion::IngestReportService).to have_received(:execute)
          .with(pipeline, report)
      end
    end

    it 'publishes the ingested SBOM event with the correct pipeline_id' do
      strategy.execute

      expect(Gitlab::EventStore).to have_received(:publish).with(
        an_instance_of(Sbom::SbomIngestedEvent).and(having_attributes(data: hash_including(pipeline_id: pipeline.id)))
      )
    end

    it 'deletes not present occurrences' do
      strategy.execute

      expect(
        Sbom::Ingestion::ContainerScanningForRegistry::DeleteNotPresentOccurrencesService
      ).to have_received(:execute).with(pipeline,
        ingested_ids, ingested_source_ids.first)
    end
  end
end
