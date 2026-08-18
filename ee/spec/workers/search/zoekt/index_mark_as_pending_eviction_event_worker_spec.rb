# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexMarkAsPendingEvictionEventWorker, :zoekt_settings_enabled,
  feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexMarkPendingEvictionEvent.new(data: {}) }

  let_it_be(:healthy_index) { create(:zoekt_index, :ready, watermark_level: :healthy) }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    context 'when no indices are should be marked as pending_eviction' do
      it 'does nothing' do
        expect { consume_event(subscriber: described_class, event: event) }
          .not_to change { healthy_index.reload.state }
      end
    end

    context 'when indices exist that should be marked as pending_eviction' do
      let_it_be_with_reload(:idx1) { create(:zoekt_index, :critical_watermark_exceeded, :ready) }
      let_it_be_with_reload(:idx2) { create(:zoekt_index, :critical_watermark_exceeded, :ready) }
      let_it_be_with_reload(:idx3) { create(:zoekt_index, :critical_watermark_exceeded, :ready) }
      let_it_be_with_reload(:idx4) { create(:zoekt_index, :critical_watermark_exceeded, :pending_eviction) }

      it 'updates the state for each index to pending_eviction' do
        expect(Search::Zoekt::Index).to receive(:should_be_pending_eviction).and_call_original
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 3)
        end

        expect { consume_event(subscriber: described_class, event: event) }
          .to change { idx1.reload.state }.from('ready').to('pending_eviction')
          .and change { idx2.reload.state }.from('ready').to('pending_eviction')
          .and change { idx3.reload.state }.from('ready').to('pending_eviction')
          .and not_change { idx4.reload.state }
          .and not_change { healthy_index.reload.state }
      end

      it 'processes in batches' do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 2)
        end

        expect { consume_event(subscriber: described_class, event: event) }
          .to change { idx1.reload.state }.from('ready').to('pending_eviction')
          .and change { idx2.reload.state }.from('ready').to('pending_eviction')

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 1)
        end

        expect { consume_event(subscriber: described_class, event: event) }
          .to change { idx3.reload.state }.from('ready').to('pending_eviction')
      end
    end
  end
end
