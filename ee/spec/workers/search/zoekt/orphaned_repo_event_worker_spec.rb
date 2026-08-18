# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::OrphanedRepoEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::OrphanedRepoEvent.new(data: {}) }
  let_it_be(:pending_repos_to_mark_as_orphaned) { create_list(:zoekt_repository, 5, state: :pending, project_id: nil) }
  let_it_be(:already_orphaned_repo) { create(:zoekt_repository, state: :orphaned) }
  let_it_be(:non_pending_repo) { create(:zoekt_repository, state: :ready) }

  it_behaves_like 'subscribes to event'
  it_behaves_like 'an idempotent worker' do
    it 'marks pending repositories without project as orphaned in batches' do
      expect(Gitlab::EventStore).not_to receive(:publish)

      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Repository.orphaned.count }.from(1).to(6)

      expect(pending_repos_to_mark_as_orphaned.map(&:reload).map(&:state)).to all(eq('orphaned'))
      expect(non_pending_repo.reload.state).to eq('ready')
    end

    context 'when there are more repositories than the batch size' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'processes only up to the batch size and schedules another event' do
        expect(Gitlab::EventStore).to receive(:publish).with(
          an_object_having_attributes(
            class: Search::Zoekt::OrphanedRepoEvent,
            data: {}
          )
        )

        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Repository.orphaned.count }.by(2)
      end
    end
  end
end
