# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::ExecutionStrategy::Default, feature_category: :dependency_management do
  let_it_be(:pipeline) { build_stubbed(:ci_pipeline) }
  let_it_be(:project) { pipeline.project }
  let_it_be(:reports) { create_list(:ci_reports_sbom_report, 4) }

  let(:report_ingested_ids) { [[1], [2], [3], [4]] }
  let(:ingested_ids) { report_ingested_ids.flatten }
  let(:ingested_source_ids) { [1] }

  subject(:strategy) { described_class.new(reports, project, pipeline) }

  before do
    allow(project).to receive(:set_latest_ingested_sbom_pipeline_id)
    allow(Sbom::Ingestion::DeleteNotPresentOccurrencesService).to receive(:execute)
    allow(Gitlab::EventStore).to receive(:publish)
  end

  describe '#execute' do
    before do
      setup_ingest_report_service
    end

    it 'ingests the reports' do
      strategy.execute

      expect_ingest_report_service_calls
    end

    it 'sets the latest ingested SBOM pipeline ID' do
      strategy.execute

      expect(project).to have_received(:set_latest_ingested_sbom_pipeline_id).with(pipeline.id)
    end

    it 'deletes not present occurrences' do
      strategy.execute

      expect(Sbom::Ingestion::DeleteNotPresentOccurrencesService).to have_received(:execute).with(pipeline,
        ingested_ids)
    end

    context 'when reports are ingested' do
      it 'publishes the ingested SBOM event' do
        strategy.execute

        expect(Gitlab::EventStore).to have_received(:publish).with(
          an_instance_of(Sbom::SbomIngestedEvent).and(having_attributes(data: hash_including(pipeline_id: pipeline.id)))
        )
      end
    end

    context 'when reports are not ingested' do
      let(:report_ingested_ids) { [[], [], [], []] }

      it 'does not publish the ingested SBOM event' do
        strategy.execute

        expect(Gitlab::EventStore).not_to have_received(:publish)
      end
    end
  end

  private

  def setup_ingest_report_service
    reports.zip(report_ingested_ids) do |report, ingested_ids|
      allow(Sbom::Ingestion::IngestReportService)
        .to receive(:execute).with(pipeline, report)
        .and_return(
          [{ occurrence_ids: ingested_ids, source_ids: ingested_source_ids }]
        )
    end
  end

  def expect_ingest_report_service_calls
    reports.each do |report|
      expect(Sbom::Ingestion::IngestReportService).to have_received(:execute)
        .with(pipeline, report)
    end
  end
end
