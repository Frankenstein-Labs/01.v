# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SegmentedExport::FinalizerService, feature_category: :shared do
  describe '#execute' do
    context 'when finalizing a Vulnerability::Export' do
      let(:export_state) { :running }
      let(:vulnerability_export) { create(:vulnerability_export, status: export_state) }
      let(:service_object) { described_class.new(vulnerability_export) }
      let(:mock_exporter_service) do
        instance_double(VulnerabilityExports::ExportService, finalise_segmented_export: true)
      end

      subject(:finalize_export) { service_object.execute }

      before do
        allow(Gitlab::Export::SegmentedExportFinalisationWorker).to receive(:perform_in)
        allow(vulnerability_export).to receive(:export_service).and_return(mock_exporter_service)
      end

      context 'when the export has taken too long to execute' do
        let(:vulnerability_export) do
          create(:vulnerability_export, created_at: (Vulnerabilities::Export::MAX_EXPORT_DURATION + 1.hour).ago)
        end

        it 'fails the export and schedules its deletion' do
          expect(vulnerability_export).to receive(:failed!)
          expect(vulnerability_export).to receive(:schedule_for_deletion)

          finalize_export
        end
      end

      context 'when there are still not finished export parts' do
        before do
          create(:vulnerability_export_part, vulnerability_export: vulnerability_export)
        end

        context 'when the export is still running' do
          it 'reschedules the `Gitlab::Export::SegmentedExportFinalisationWorker`' do
            finalize_export

            expect(Gitlab::Export::SegmentedExportFinalisationWorker).to have_received(:perform_in)
            expect(mock_exporter_service).not_to have_received(:finalise_segmented_export)
          end
        end

        context 'when the export is failed' do
          let(:export_state) { :failed }

          it 'does not reschedule the `Gitlab::Export::SegmentedExportFinalisationWorker`' do
            finalize_export

            expect(Gitlab::Export::SegmentedExportFinalisationWorker).not_to have_received(:perform_in)
            expect(mock_exporter_service).not_to have_received(:finalise_segmented_export)
          end
        end
      end

      context 'when all the export parts are finished' do
        before do
          create(:vulnerability_export_part, vulnerability_export: vulnerability_export, file: Tempfile.new)
        end

        context 'when the export is still in running state' do
          it 'delegates the finalization work to related service class' do
            finalize_export

            expect(mock_exporter_service).to have_received(:finalise_segmented_export)
          end
        end

        context 'when the export is in failed state' do
          let(:export_state) { :failed }

          it 'does not reschedule the work and does not delegate the finalization work to related service' do
            finalize_export

            expect(Gitlab::Export::SegmentedExportFinalisationWorker).not_to have_received(:perform_in)
            expect(mock_exporter_service).not_to have_received(:finalise_segmented_export)
          end
        end
      end
    end
  end
end
