# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dependencies::Export::SegmentCreatorService, feature_category: :dependency_management do
  describe '.execute' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be(:sbom_occurrences) { create_list(:sbom_occurrence, 5, traversal_ids: group.traversal_ids) }

    let(:export) { create(:dependency_list_export, exportable: group, project: nil) }

    subject(:create_segments) { described_class.execute(export) }

    before do
      stub_const("#{described_class}::BATCH_SIZE", 1)

      allow(Gitlab::Export::SegmentedExportWorker).to receive(:perform_async)
      allow(Gitlab::Export::SegmentedExportFinalisationWorker).to receive(:perform_async)
    end

    it 'creates export parts' do
      expect { create_segments }.to change { export.export_parts.count }.from(0).to(5)
    end

    it 'sets the correct start and end IDs for the export parts' do
      create_segments

      expect(export.export_parts.first)
        .to have_attributes(start_id: sbom_occurrences.first.id, end_id: sbom_occurrences.first.id)
      expect(export.export_parts.second)
        .to have_attributes(start_id: sbom_occurrences.second.id, end_id: sbom_occurrences.second.id)
      expect(export.export_parts.third)
        .to have_attributes(start_id: sbom_occurrences.third.id, end_id: sbom_occurrences.third.id)
      expect(export.export_parts.fourth)
        .to have_attributes(start_id: sbom_occurrences.fourth.id, end_id: sbom_occurrences.fourth.id)
      expect(export.export_parts.fifth)
        .to have_attributes(start_id: sbom_occurrences.fifth.id, end_id: sbom_occurrences.fifth.id)
    end

    it 'schedules `SegmentedExportWorker`' do
      create_segments

      expect(Gitlab::Export::SegmentedExportWorker)
        .to have_received(:perform_async).with(export.to_global_id, [export.export_parts.first.id])
      expect(Gitlab::Export::SegmentedExportWorker)
        .to have_received(:perform_async).with(export.to_global_id, [export.export_parts.second.id])
      expect(Gitlab::Export::SegmentedExportWorker)
        .to have_received(:perform_async).with(export.to_global_id, [export.export_parts.third.id])
      expect(Gitlab::Export::SegmentedExportWorker)
        .to have_received(:perform_async).with(export.to_global_id, [export.export_parts.fourth.id])
      expect(Gitlab::Export::SegmentedExportWorker)
        .to have_received(:perform_async).with(export.to_global_id, [export.export_parts.fifth.id])
    end

    context 'when there are no vulnerabilities for the vulnerable' do
      let(:group_without_vulnerabilities) { create(:group, organization: organization) }
      let(:export) { create(:dependency_list_export, exportable: group_without_vulnerabilities, project: nil) }

      it 'does not raise an error' do
        expect { create_segments }.not_to raise_error

        expect(Gitlab::Export::SegmentedExportFinalisationWorker)
          .to have_received(:perform_async).with(export.to_global_id)
      end
    end

    context 'when an error happens' do
      before do
        allow(export).to receive(:export_parts).and_raise(RuntimeError.new)
      end

      it 'resets the state of the export and propagates the error' do
        expect { create_segments }.to raise_error(RuntimeError)
                                  .and not_change { export.status }
      end
    end
  end
end
