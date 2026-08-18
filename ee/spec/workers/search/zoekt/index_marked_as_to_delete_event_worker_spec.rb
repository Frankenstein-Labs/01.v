# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexMarkedAsToDeleteEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexMarkedAsToDeleteEvent.new(data: {}) }

  let_it_be(:idx) { create(:zoekt_index, :pending_deletion) }
  let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when there an index that has zoekt repositories' do
      let_it_be(:repo_ready) { create(:zoekt_repository, zoekt_index: idx, project: idx_project, state: :ready) }
      let_it_be(:repo_pending_deletion) { create(:zoekt_repository, zoekt_index: idx, state: :pending_deletion) }

      it 'marks the non pending_deletion repositories to be deleted' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { repo_ready.reload.state }.from("ready").to("pending_deletion")
          .and not_change { repo_pending_deletion.reload.state }
      end

      it 'does not destroy the index' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Index.count }
      end

      it 'only processes a single batch of index records' do
        idx_2 = create(:zoekt_index, :pending_deletion)
        repo_2 = create(:zoekt_repository, zoekt_index: idx_2, state: :ready)

        stub_const("#{described_class}::INDEX_BATCH_SIZE", 1)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_destroyed_count, 0)
          expect(instance).to receive(:log_extra_metadata_on_done).with(:repositories_updated_count, 1)
        end

        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { repo_ready.reload.state }.from('ready').to('pending_deletion')
          .and not_change { repo_2.reload.state }
      end

      it 'processes in repositories batches', :freeze_time do
        repo_batch_size = 2
        stub_const("#{described_class}::REPO_BATCH_SIZE", repo_batch_size)

        stubbed_repositories = create_list(:zoekt_repository, 3, zoekt_index: idx, state: :ready)

        expect(Search::Zoekt::Index).to receive_message_chain(:should_be_deleted,
          :ordered, :limit, :find_each).and_yield(idx)

        allow(idx).to receive_message_chain(:zoekt_repositories, :exists?).and_return(true)
        allow(idx).to receive_message_chain(:zoekt_repositories, :not_pending_deletion).and_return(stubbed_repositories)

        batch_double = instance_double(ActiveRecord::Relation, update_all: 2)
        allow(stubbed_repositories).to receive(:each_batch).with(of: repo_batch_size, column: :project_id)
          .and_yield(batch_double).and_yield(batch_double)
        expect(batch_double).to receive(:update_all).with(state: :pending_deletion, updated_at: Time.current)
          .twice.and_return(2)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_destroyed_count, 0)
          expect(instance).to receive(:log_extra_metadata_on_done).with(:repositories_updated_count, 4)
        end

        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when there is an index that does not have any zoekt repositories' do
      it 'destroys the zoekt index' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_destroyed_count, 1)
          expect(instance).to receive(:log_extra_metadata_on_done).with(:repositories_updated_count, 0)
        end

        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Index.count }.from(1).to(0)
      end
    end
  end
end
