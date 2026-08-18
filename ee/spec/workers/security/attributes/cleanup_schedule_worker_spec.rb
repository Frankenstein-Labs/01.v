# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Attributes::CleanupScheduleWorker, feature_category: :security_asset_inventories do
  let(:worker) { described_class.new }
  let(:group_transfer_event) do
    Groups::GroupTransferedEvent.new(data: {
      group_id: group_id,
      old_root_namespace_id: old_root_namespace_id,
      new_root_namespace_id: new_root_namespace_id
    })
  end

  let_it_be(:old_root_namespace) { create(:group) }
  let_it_be(:new_root_namespace) { create(:group) }
  let_it_be(:moved_group) { create(:group, parent: new_root_namespace) }

  let(:group_id) { moved_group.id }
  let(:old_root_namespace_id) { old_root_namespace.id }
  let(:new_root_namespace_id) { new_root_namespace.id }
  let(:cleanup_batch_worker) { Security::Attributes::CleanupBatchWorker }
  let(:namespace_project_ids_batch) { instance_double(Gitlab::Database::NamespaceProjectIdsEachBatch) }

  subject(:handle_event) { worker.handle_event(group_transfer_event) }

  describe '#handle_event' do
    before do
      allow(cleanup_batch_worker).to receive(:perform_async)
    end

    context 'when root namespace has not changed' do
      let(:old_root_namespace_id) { new_root_namespace.id }
      let(:new_root_namespace_id) { new_root_namespace.id }

      context 'when no projects exist under the group' do
        it 'does not schedule the workers' do
          handle_event

          expect(cleanup_batch_worker).not_to have_received(:perform_async)
        end
      end

      context 'when projects exist under the group' do
        let_it_be(:projects_same_ns) { create_list(:project, 2, group: moved_group) }
        let(:project_ids_same_ns) { projects_same_ns.pluck(:id) }

        it 'schedules workers with nil new_root_namespace_id to update traversal_ids only' do
          handle_event

          expect(cleanup_batch_worker).to have_received(:perform_async).with(match_array(project_ids_same_ns), nil)
        end
      end
    end

    context 'when moved group no longer not exist' do
      let(:group_id) { non_existing_record_id }

      it 'does not schedule any workers' do
        handle_event

        expect(cleanup_batch_worker).not_to have_received(:perform_async)
      end
    end

    context 'when root namespace has changed and group exists' do
      context 'when no projects exist under the group' do
        it 'does not schedule any workers' do
          handle_event

          expect(cleanup_batch_worker).not_to have_received(:perform_async)
        end
      end

      context 'with projects exists under the group' do
        let_it_be(:projects) { create_list(:project, 3, group: moved_group) }
        let(:project_ids) { projects.map(&:id) }

        it 'schedules update batch workers' do
          handle_event

          expect(cleanup_batch_worker).to have_received(:perform_async).with(match_array(project_ids),
            new_root_namespace.id)
        end

        context 'with large number of projects requiring batching' do
          before do
            stub_const('Security::Attributes::CleanupScheduleWorker::PROJECTS_BATCH_SIZE', 1)
          end

          it 'schedules multiple batch workers with correct batch sizes' do
            handle_event

            project_ids.each do |project_id|
              expect(cleanup_batch_worker).to have_received(:perform_async).with([project_id], new_root_namespace.id)
            end
          end

          it 'schedules the correct number of batch workers' do
            handle_event

            expect(cleanup_batch_worker).to have_received(:perform_async).exactly(project_ids.size).times
          end
        end
      end
    end
  end
end
