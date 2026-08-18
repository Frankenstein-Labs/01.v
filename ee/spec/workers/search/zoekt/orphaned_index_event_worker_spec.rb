# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::OrphanedIndexEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::OrphanedIndexEvent.new(data: {}) }
  let_it_be_with_reload(:idx) { create(:zoekt_index) }
  let_it_be_with_reload(:idx2) { create(:zoekt_index) }
  let_it_be_with_reload(:idx3) { create(:zoekt_index) }
  let_it_be_with_reload(:idx4) { create(:zoekt_index) }

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when there are indices that should be marked as orphaned' do
      let(:batch_size) { described_class::BATCH_SIZE }

      before do
        Search::Zoekt::Index.update_all(zoekt_replica_id: nil)
      end

      it 'moves all indices that should be marked as orphaned to orphaned' do
        expect([idx, idx2, idx3, idx4].all? { |i| i.reload.pending? }).to be true
        expect_next_instance_of(described_class) do |i|
          expect(i).to receive(:log_extra_metadata_on_done).with(:indices_orphaned_count, 4) # idx, idx2, idx5
        end
        consume_event(subscriber: described_class, event: event)
        expect([idx, idx2, idx3, idx4].all? { |i| i.reload.orphaned? }).to be true
      end

      it 'only processes a single batch of index records', :freeze_time do
        scope = Search::Zoekt::Index.limit(batch_size)
        allow(Search::Zoekt::Index).to receive_message_chain(:should_be_marked_as_orphaned, :ordered).and_return(scope)
        expect(scope).to receive(:limit).with(batch_size).and_return(scope)
        expect(scope).to receive(:update_all).with(state: :orphaned, updated_at: Time.current).exactly(:once)
        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when there are no indices that should be marked as orphaned' do
      it 'does not log anything and does not update indices' do
        expect([idx, idx2, idx3, idx4].all? { |i| i.reload.pending? }).to be true
        expect_next_instance_of(described_class) { |i| expect(i).not_to receive(:log_extra_metadata_on_done) }
        consume_event(subscriber: described_class, event: event)
        expect([idx, idx2, idx3, idx4].all? { |i| i.reload.pending? }).to be true
      end
    end
  end
end
