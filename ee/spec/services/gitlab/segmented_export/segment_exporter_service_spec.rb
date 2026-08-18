# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::SegmentedExport::SegmentExporterService, feature_category: :shared do
  describe '#execute' do
    context 'when exporting a segment for Vulnerability::Export' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:group) { create(:group, organization: organization) }
      let_it_be(:project) { create(:project, namespace: group) }
      let_it_be(:vulnerability_export) { create(:vulnerability_export, :created, exportable: group) }
      let_it_be(:vulnerability_reads) { create_list(:vulnerability_read, 2, project: project) }
      let_it_be(:export_part_1) do
        create(:vulnerability_export_part,
          vulnerability_export: vulnerability_export,
          start_id: vulnerability_reads.first.id,
          end_id: vulnerability_reads.first.id)
      end

      let_it_be(:export_part_2) do
        create(:vulnerability_export_part,
          vulnerability_export: vulnerability_export,
          start_id: vulnerability_reads.second.id,
          end_id: vulnerability_reads.second.id)
      end

      let(:export_service_mock) { instance_double(VulnerabilityExports::ExportService, export_segment: true) }
      let(:service_object) { described_class.new(vulnerability_export, [export_part_1.id, export_part_2.id]) }

      subject(:export_segment) { service_object.execute }

      before do
        allow(Gitlab::Export::SegmentedExportFinalisationWorker).to receive(:perform_async)
      end

      it 'generates the partial exports for each part' do
        expect { export_segment }.to change { export_part_1.reload.file.file }.from(nil)
                                 .and change { export_part_2.reload.file.file }.from(nil)

        csv_1 = CSV.parse(export_part_1.file.read, headers: true)
        csv_2 = CSV.parse(export_part_2.file.read, headers: true)

        expect(csv_1.length).to be(1)
        expect(csv_2.length).to be(1)
      end

      it 'enqueues the export finalisation' do
        export_segment

        expect(Gitlab::Export::SegmentedExportFinalisationWorker).to have_received(:perform_async).with(
          vulnerability_export.to_global_id
        )
      end
    end
  end
end
