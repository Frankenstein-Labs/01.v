# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexToEvictEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexToEvictEvent.new(data: {}) }

  let_it_be(:healthy_index) { create(:zoekt_index, watermark_level: :healthy) }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    context 'when no indices are pending_eviction' do
      it 'does nothing' do
        expect { consume_event(subscriber: described_class, event: event) }.not_to change {
          ::Search::Zoekt::Replica.count
        }
      end
    end

    context 'when indices pending_eviction' do
      let_it_be_with_reload(:idx1) { create(:zoekt_index, :pending_eviction) }
      let_it_be_with_reload(:idx2) { create(:zoekt_index, :pending_eviction) }
      let_it_be_with_reload(:idx3) { create(:zoekt_index, :pending_eviction) }

      it 'deletes associated replicas and logs metadata with deleted count' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_hash_metadata_on_done)
            .with({ replicas_deleted_count: 3, indices_updated_count: 3 })
        end

        expect { consume_event(subscriber: described_class, event: event) }
          .to change { ::Search::Zoekt::Replica.count }.by(-3)
          .and change { idx1.reload.state }.from('pending_eviction').to('evicted')
          .and change { idx2.reload.state }.from('pending_eviction').to('evicted')
          .and change { idx3.reload.state }.from('pending_eviction').to('evicted')
          .and not_change { healthy_index.reload.state }
      end

      it 'processes in batches' do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_hash_metadata_on_done)
            .with({ replicas_deleted_count: 2, indices_updated_count: 2 })
        end

        expect { consume_event(subscriber: described_class, event: event) }
        .to change { ::Search::Zoekt::Replica.count }.by(-2)
        .and change { idx1.reload.state }.from('pending_eviction').to('evicted')
        .and change { idx2.reload.state }.from('pending_eviction').to('evicted')

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_hash_metadata_on_done)
            .with({ replicas_deleted_count: 1, indices_updated_count: 1 })
        end

        expect { consume_event(subscriber: described_class, event: event) }
          .to change { ::Search::Zoekt::Replica.count }.by(-1)
          .and change { idx3.reload.state }.from('pending_eviction').to('evicted')
      end
    end
  end
end
