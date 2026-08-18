# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::NamespaceStatistics::ProcessGroupDeleteEventsWorker, feature_category: :security_asset_inventories do
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

    let(:recalculate_service) { Vulnerabilities::NamespaceStatistics::RecalculateService }

    subject(:handle_event) { worker.handle_event(event) }

    before do
      allow(recalculate_service).to receive(:execute)

      create(:vulnerability_statistic, project: project)
      create(:vulnerability_statistic, project: archived_project, archived: true)
    end

    context 'when there is no parent group associated with the event' do
      let(:parent_namespace_id) { non_existing_record_id }

      it 'does not delete any statistics or call recalculate service' do
        expect { handle_event }.not_to change { Vulnerabilities::Statistic.count }
        expect(recalculate_service).not_to have_received(:execute)
      end
    end

    context 'when there is a parent group associated with the event' do
      let(:parent_namespace_id) { parent_group.id }

      it 'deletes only the unarchived statistics records for the deleted group' do
        expect { handle_event }.to change { Vulnerabilities::Statistic.where(project_id: project.id).count }.to(0)
         .and not_change { Vulnerabilities::Statistic.where(project_id: archived_project.id).count }
      end

      it 'calls the recalculate service with the parent group' do
        handle_event

        expect(recalculate_service).to have_received(:execute).with(parent_group)
      end

      context 'when batch deleting' do
        let(:statistic) { class_double(Vulnerabilities::Statistic).as_stubbed_const }
        let(:traversal_ids) { deleted_group.traversal_ids }
        let(:next_traversal_ids) { deleted_group.next_traversal_ids }

        before do
          stub_const("#{described_class}::BATCH_SIZE", 1)

          allow(statistic).to receive(:unarchived).and_return(statistic)
          allow(statistic).to receive(:within).with(traversal_ids).and_return(statistic)
          allow(statistic).to receive(:limit).with(1).and_return(statistic)
          allow(statistic).to receive(:delete_all).and_return(1, 1, 0)
        end

        it 'deletes all statistics in batches' do
          expect(statistic).to receive(:delete_all).at_least(:twice)
          handle_event
        end

        it 'calls group_projects_statistics with the correct parameters' do
          expect(worker).to receive(:group_projects_statistics)
            .with(parent_group, deleted_group.id).at_least(:once).and_call_original
          handle_event
        end
      end
    end
  end
end
