# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoToIndexEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::RepoToIndexEvent.new(data: {}) }

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when zoekt is disabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return false
      end

      it 'does not create any indexing tasks' do
        expect do
          consume_event(subscriber: described_class, event: event)
        end.not_to change { Search::Zoekt::Task.count }
      end
    end

    context 'when zoekt is enabled' do
      before do
        allow(Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return true
      end

      context 'with repositories within batch size' do
        it 'creates indexing tasks for Search::Zoekt::Repository without re-emitting event' do
          batch_size = 2
          create_list(:zoekt_repository, batch_size, state: :pending)
          stub_const("#{described_class}::BATCH_SIZE", batch_size)

          expect(Gitlab::EventStore).not_to receive(:publish)

          expect do
            consume_event(subscriber: described_class, event: event)
          end.to change { Search::Zoekt::Task.count }.from(0).to(batch_size)
        end
      end

      context 'with more repositories than batch size' do
        before do
          stub_const("#{described_class}::BATCH_SIZE", 2)
          create_list(:zoekt_repository, 5, state: :pending)
        end

        it 'processes batch size and schedules another event' do
          expect(Gitlab::EventStore).to receive(:publish).with(
            an_object_having_attributes(class: Search::Zoekt::RepoToIndexEvent, data: {})
          )

          expect { consume_event(subscriber: described_class, event: event) }
            .to change { Search::Zoekt::Task.count }.by(2)
        end
      end
    end
  end
end
