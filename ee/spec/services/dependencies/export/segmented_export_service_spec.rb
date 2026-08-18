# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::Export::SegmentedExportService, feature_category: :dependency_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }

  let(:export_type) { :json_array }
  let(:export) { create(:dependency_list_export, :running, export_type: export_type, exportable: group, project: nil) }
  let(:service_object) { described_class.new(export) }

  def stub_file(content)
    file = Tempfile.new
    file.write(content)
    file.rewind
    file
  end

  where(:export_type, :exporter_class) do
    :json_array | ::Sbom::Exporters::JsonArrayService
    :csv        | ::Sbom::Exporters::CsvService
  end

  describe '#export_segment' do
    let_it_be(:sbom_occurrence) { create(:sbom_occurrence, traversal_ids: group.traversal_ids) }

    let!(:export_part) do
      create(:dependency_list_export_part,
        dependency_list_export: export,
        start_id: sbom_occurrence.id,
        end_id: sbom_occurrence.id)
    end

    let(:content) { "export part content" }
    let(:file) { stub_file(content) }

    subject(:export_segment) { service_object.export_segment(export_part) }

    before_all do
      create(:sbom_occurrence, traversal_ids: group.traversal_ids)
    end

    with_them do
      it 'uses file from exporter' do
        expect_next_instance_of(exporter_class, export, export_part.sbom_occurrences) do |instance|
          expect(instance).to receive(:generate_part).and_yield(file)
        end

        export_segment

        expect(export_part.file.file.read).to eq(content)
      end

      it 'writes content when calling original implementation' do
        export_segment

        expect(export_part.file.file.read.size).to be > 0
      end
    end

    it 'creates the file for the export part' do
      expect { export_segment }.to change { export_part.file.file }.from(nil)
    end

    context 'when an error happens' do
      let(:error) { RuntimeError.new }

      before do
        allow(export_part).to receive(:sbom_occurrences).and_raise(error)
        allow(Dependencies::DestroyExportWorker).to receive(:perform_in)
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it 'marks the export as failed' do
        expect { export_segment }.to change { export.failed? }.to(true)
      end

      it 'tracks the exception and schedules export deletion worker' do
        export_segment

        expect(Gitlab::ErrorTracking).to have_received(:track_and_raise_for_dev_exception).with(error)
        expect(Dependencies::DestroyExportWorker).to have_received(:perform_in).with(1.hour, export.id)
      end
    end
  end

  describe '#finalise_segmented_export' do
    subject(:finalise_export) { service_object.finalise_segmented_export }

    let(:content) { "combined export content" }
    let(:file) { stub_file(content) }
    let(:export_parts) do
      create_list(:dependency_list_export_part, 2, :exported, dependency_list_export: export)
    end

    before do
      allow(Dependencies::DestroyExportWorker).to receive(:perform_in)
    end

    it_behaves_like 'large segmented file export'

    it 'creates the file for the export and marks the export as finished' do
      expect { finalise_export }.to change { export.file.file }.from(nil)
                                .and change { export.finished? }.to(true)
    end

    with_them do
      it 'uses exporter to combine export parts' do
        expect(export_class).to receive(:combine_parts)
          .with(export_parts.map(&:file)).and_yield(file)

        finalise_export

        expect(export.file.read).to eq(content)
      end

      it 'writes content when calling original implementation' do
        finalise_export

        expect(export.file.read.size).to be > 0
      end
    end

    it 'schedules the export deletion' do
      expect(export).to receive(:schedule_export_deletion)

      finalise_export
    end

    context 'when an error happens' do
      let(:error) { RuntimeError.new }

      before do
        allow(export).to receive(:export_parts).and_raise(error)
        allow(Dependencies::DestroyExportWorker).to receive(:perform_in)
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      it 'marks the export as failed' do
        expect { finalise_export }.to change { export.failed? }.to(true)
      end

      it 'tracks the exception and schedules export deletion worker' do
        finalise_export

        expect(Gitlab::ErrorTracking).to have_received(:track_and_raise_for_dev_exception).with(error)
        expect(Dependencies::DestroyExportWorker).to have_received(:perform_in).with(1.hour, export.id)
      end
    end
  end
end
