# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexMarkedAsReadyEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexMarkedAsReadyEvent.new(data: {}) }

  let_it_be_with_reload(:idx) { create(:zoekt_index, state: :initializing) }
  let_it_be_with_reload(:_zoekt_repo) { create(:zoekt_repository, zoekt_index: idx, state: :ready) }
  let_it_be_with_reload(:idx2) { create(:zoekt_index, state: :initializing) }
  let_it_be_with_reload(:_zoekt_repo2) { create(:zoekt_repository, zoekt_index: idx2, state: :ready) }
  let_it_be_with_reload(:_zoekt_repo3) { create(:zoekt_repository, zoekt_index: idx2, state: :failed) }
  let_it_be_with_reload(:idx3) { create(:zoekt_index, state: :initializing) }
  let_it_be_with_reload(:_zoekt_repo4) { create(:zoekt_repository, zoekt_index: idx3) }
  let_it_be_with_reload(:idx4) { create(:zoekt_index, state: :ready) }
  let_it_be_with_reload(:_zoekt_repo5) { create(:zoekt_repository, zoekt_index: idx4, state: :ready) }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    context 'when there are initializing indices that have all finished repositories' do
      let_it_be_with_reload(:idx5) { create(:zoekt_index, state: :initializing) }
      let(:batch) { described_class::BATCH_SIZE }

      it 'moves all indices to ready that has all finished repositories' do
        expect([idx, idx2, idx3, idx4, idx5].map do |i|
          i.reload.state
        end).to eq(%w[initializing initializing initializing ready initializing])
        expect_next_instance_of(described_class) do |i|
          expect(i).to receive(:log_extra_metadata_on_done).with(:indices_ready_count, 3) # idx, idx2, idx5
        end
        consume_event(subscriber: described_class, event: event)
        expect([idx, idx2, idx3, idx4, idx5].map { |i| i.reload.state }).to eq(%w[ready ready initializing ready ready])
        expect(idx2.reload).to be_ready
        expect(idx3.reload).to be_initializing
        expect(idx4.reload).to be_ready
        expect(idx5.reload).to be_ready
      end

      it 'processes single batch' do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        ids = Search::Zoekt::Index.initializing.with_all_finished_repositories.ordered.limit(batch).pluck_primary_key
        indices = Search::Zoekt::Index.id_in(ids)
        expect(indices.all?(&:initializing?)).to be true
        expect_next_instance_of(described_class) do |i|
          expect(i).to receive(:log_extra_metadata_on_done).with(:indices_ready_count, batch)
        end
        consume_event(subscriber: described_class, event: event)
        indices = Search::Zoekt::Index.id_in(ids)
        expect(indices.all?(&:ready?)).to be true
        rest_indices = Search::Zoekt::Index.initializing.with_all_finished_repositories.ordered.offset(batch)
        expect(rest_indices.all?(&:initializing?)).to be true
      end
    end

    context 'when there are no initializing indices with all finished repositories' do
      before do
        Search::Zoekt::Repository.update_all(state: :pending)
      end

      it 'does not log anything and does not update indices' do
        initial_indices_states = Search::Zoekt::Index.pluck(:id, :state)

        expect_next_instance_of(described_class) { |i| expect(i).not_to receive(:log_extra_metadata_on_done) }
        consume_event(subscriber: described_class, event: event)
        expect(Search::Zoekt::Index.pluck(:id, :state)).to match(initial_indices_states)
      end
    end
  end
end
