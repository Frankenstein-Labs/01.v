# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::AnalyzerNamespaceStatuses::ProcessGroupDeletedEventsWorker, feature_category: :security_asset_inventories, type: :job do
  let(:worker) { described_class.new }

  describe '#handle_event' do
    let_it_be(:parent_group) { create(:group) }
    let_it_be(:deleted_group) { create(:group, parent: parent_group) }
    let_it_be(:project) { create(:project, group: deleted_group) }
    let_it_be(:archived_project) { create(:project, group: deleted_group, archived: true) }

    let(:event) do
      Groups::GroupDeletedEvent.new(data: {
        group_id: deleted_group.id,
        root_namespace_id: parent_namespace_id,
        parent_namespace_id: parent_namespace_id
      })
    end

    let(:recalculate_service) { Security::AnalyzerNamespaceStatuses::RecalculateService }

    subject(:handle_event) { worker.handle_event(event) }

    before do
      allow(recalculate_service).to receive(:execute)

      create(:analyzer_project_status, project: project)
      create(:analyzer_project_status, project: archived_project, archived: true)
    end

    context 'when there is no parent group associated with the event' do
      let(:parent_namespace_id) { non_existing_record_id }

      it 'does not delete any analyzer_project_statuses or call recalculate service' do
        expect { handle_event }.not_to change { Security::AnalyzerProjectStatus.count }
        expect(recalculate_service).not_to have_received(:execute)
      end
    end

    context 'when there is a parent group associated with the event' do
      let(:parent_namespace_id) { parent_group.id }

      it 'deletes only the unarchived analyzer_project_statuses records for the deleted group' do
        expect { handle_event }.to change { Security::AnalyzerProjectStatus.where(project_id: project.id).count }.to(0)
         .and not_change { Security::AnalyzerProjectStatus.where(project_id: archived_project.id).count }
      end

      it 'calls the recalculate service with the parent group' do
        handle_event

        expect(recalculate_service).to have_received(:execute).with(parent_group)
      end

      context 'when batch deleting' do
        let(:analyzer_status) { class_double(Security::AnalyzerProjectStatus).as_stubbed_const }
        let(:traversal_ids) { deleted_group.traversal_ids }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)

          allow(analyzer_status).to receive(:unarchived).and_return(analyzer_status)
          allow(analyzer_status).to receive(:within).with(traversal_ids).and_return(analyzer_status)
          allow(analyzer_status).to receive(:limit).with(1).and_return(analyzer_status)
          allow(analyzer_status).to receive(:delete_all).and_return(1, 1, 0)
        end

        it 'deletes all analyzer_project_statuses in batches' do
          expect(analyzer_status).to receive(:delete_all).at_least(:twice)
          handle_event
        end

        it 'calls group_analyzer_projects_statuses with the correct parameters' do
          expect(worker).to receive(:group_analyzer_projects_statuses)
            .with(parent_group, deleted_group.id).at_least(:once).and_call_original
          handle_event
        end
      end
    end
  end
end
