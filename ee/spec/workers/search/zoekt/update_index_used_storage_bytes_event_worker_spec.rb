# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::UpdateIndexUsedStorageBytesEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::UpdateIndexUsedStorageBytesEvent.new(data: {}) }
  let(:time) { Time.zone.now }

  # Stale | Correct used_storage_bytes should be 3*20
  let_it_be_with_reload(:idx) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at, used_storage_bytes: 10)
  end

  # Stale | Correct used_storage_bytes should be 3*20
  let_it_be_with_reload(:idx2) { create(:zoekt_index, used_storage_bytes: 10) }

  # Stale | Correct used_storage_bytes should be default_used_storage_bytes
  let_it_be_with_reload(:idx_empty_repos) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at)
  end

  # Stale | Correct used_storage_bytes should be default_used_storage_bytes
  let_it_be_with_reload(:idx_without_repos) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at)
  end

  # Stale | Correct used_storage_bytes should be 3*30
  let_it_be_with_reload(:idx_correct_used_storage_bytes) do
    create(:zoekt_index, :stale_used_storage_bytes_updated_at, used_storage_bytes: 90)
  end

  # Not Stale | Correct used_storage_bytes should be 3*20
  let_it_be_with_reload(:idx_out_of_scope) do
    create(:zoekt_index, used_storage_bytes: 10, last_indexed_at: 1.minute.ago,
      used_storage_bytes_updated_at: Time.zone.now)
  end

  let(:indices) { [idx, idx2, idx_empty_repos, idx_without_repos, idx_correct_used_storage_bytes, idx_out_of_scope] }
  let(:default_used_storage_bytes) { Search::Zoekt::Index::DEFAULT_USED_STORAGE_BYTES }

  before_all do
    create_list(:zoekt_repository, 3, zoekt_index: idx, size_bytes: 20)
    create_list(:zoekt_repository, 3, zoekt_index: idx2, size_bytes: 20)
    create_list(:zoekt_repository, 3, zoekt_index: idx_empty_repos, size_bytes: 0)
    create_list(:zoekt_repository, 3, zoekt_index: idx_correct_used_storage_bytes, size_bytes: 30)
    create_list(:zoekt_repository, 3, zoekt_index: idx_out_of_scope, size_bytes: 20)
  end

  it_behaves_like 'subscribes to event'

  context 'when Zoekt is not licensed or indexing is disabled' do
    before do
      allow(::Search::Zoekt).to receive(:licensed_and_indexing_enabled?).and_return(false)
    end

    it 'does not update used_storage_bytes of indices which are the part of with_stale_used_storage_bytes_updated_at' do
      expect(indices.map { |i| i.reload.used_storage_bytes }).to eq [10, 10, 0, 0, 90, 10]
      consume_event(subscriber: described_class, event: event)
      expect(indices.map { |i| i.reload.used_storage_bytes }).to eq [10, 10, 0, 0, 90, 10]
    end
  end

  it_behaves_like 'an idempotent worker', :freeze_time do
    it 'updates used_storage_bytes of indices which are the part of with_stale_used_storage_bytes_updated_at' do
      expect(indices.map { |i| i.reload.used_storage_bytes }).to eq [10, 10, 0, 0, 90, 10]
      consume_event(subscriber: described_class, event: event)
      expected = [60, 60, default_used_storage_bytes, default_used_storage_bytes, 90, 10]
      expect(indices.map { |i| i.reload.used_storage_bytes }).to eq expected
    end

    context 'when there are more indices than the batch size' do
      before do
        stub_const("#{described_class}::BATCH_SIZE", 2)
      end

      it 'updates used_storage_bytes by order of when they were last updated' do
        older_time = 3.days.ago
        middle_time = 2.days.ago
        newer_time = 1.day.ago

        idx.update!(used_storage_bytes_updated_at: older_time)
        idx2.update!(used_storage_bytes_updated_at: middle_time)
        idx_correct_used_storage_bytes.update!(used_storage_bytes_updated_at: newer_time)

        expect(indices.map { |i| i.reload.used_storage_bytes }).to eq [10, 10, 0, 0, 90, 10]
        consume_event(subscriber: described_class, event: event)

        expected = [60, 10, 0, 0, 90, 10]
        expect(indices.map { |i| i.reload.used_storage_bytes }).to eq expected

        consume_event(subscriber: described_class, event: event)
        expected = [60, 10, default_used_storage_bytes, default_used_storage_bytes, 90, 10]
        expect(indices.map { |i| i.reload.used_storage_bytes }).to eq expected
      end

      it 'processes only up to the batch size and schedules another event' do
        expect(Gitlab::EventStore).to receive(:publish).with(
          an_object_having_attributes(class: Search::Zoekt::UpdateIndexUsedStorageBytesEvent, data: {})
        )

        expect do
          consume_event(subscriber: described_class, event: event)
        end.to change { Search::Zoekt::Index.with_stale_used_storage_bytes_updated_at.count }.by(-2)
      end
    end
  end

  context 'when there are no stale indices' do
    before do
      Search::Zoekt::Index.update_all(
        used_storage_bytes_updated_at: Time.zone.now,
        last_indexed_at: 1.minute.ago
      )
    end

    it 'does nothing and does not raise' do
      expect { consume_event(subscriber: described_class, event: event) }.not_to raise_error
    end
  end

  context 'when reserved_storage_bytes does not change after update (delta == 0)' do
    # An index with state `pending` (not ready) and large reserved_storage_bytes will
    # skip reducing reserved_storage_bytes in refresh_reserved_storage_bytes, producing delta == 0.
    let_it_be_with_reload(:idx_pending) do
      create(:zoekt_index, :stale_used_storage_bytes_updated_at, reserved_storage_bytes: 100_000)
    end

    before_all do
      # small repos so that ideal_reserved < reserved, triggering the "not ready" early return
      create_list(:zoekt_repository, 1, zoekt_index: idx_pending, size_bytes: 1)
    end

    it 'skips cache adjustment when delta is zero and does not raise', :freeze_time do
      # reserved_storage_bytes should remain unchanged since index is not ready
      # (ideal < reserved && !ready? triggers early return in refresh_reserved_storage_bytes)
      expect { consume_event(subscriber: described_class, event: event) }.not_to raise_error

      expect(idx_pending.reload.reserved_storage_bytes).to eq(100_000)
    end
  end

  describe 'batch query optimization' do
    it 'preloads zoekt_enabled_namespace to avoid N+1 queries on save', :freeze_time do
      recorder = ActiveRecord::QueryRecorder.new { consume_event(subscriber: described_class, event: event) }

      # With preloading, zoekt_enabled_namespaces should be fetched in one batch (IN (...)),
      # never as individual per-row lookups (WHERE id = ? LIMIT 1)
      per_row_loads = recorder.log.count do |q|
        q.include?('zoekt_enabled_namespaces') && q.include?('LIMIT 1')
      end

      expect(per_row_loads).to eq(0),
        "Expected no per-row zoekt_enabled_namespace SELECTs (N+1), got #{per_row_loads}"
    end

    it 'issues a single bulk UPDATE instead of per-index UPDATEs', :freeze_time do
      recorder = ActiveRecord::QueryRecorder.new { consume_event(subscriber: described_class, event: event) }

      update_queries = recorder.log.select do |q|
        q.include?('UPDATE') && q.include?('zoekt_indices')
      end

      # The bulk-UPDATE path must fire exactly one UPDATE regardless of index count.
      expect(update_queries.count).to eq(1),
        "Expected exactly 1 UPDATE zoekt_indices (bulk), got #{update_queries.count}:\n#{update_queries.join("\n")}"
    end

    context 'when multiple indices share the same node' do
      let_it_be(:shared_node) { create(:zoekt_node) }
      let_it_be_with_reload(:idx_a) do
        create(:zoekt_index, :stale_used_storage_bytes_updated_at,
          node: shared_node, used_storage_bytes: 10)
      end

      let_it_be_with_reload(:idx_b) do
        create(:zoekt_index, :stale_used_storage_bytes_updated_at,
          node: shared_node, used_storage_bytes: 10)
      end

      before_all do
        create_list(:zoekt_repository, 3, zoekt_index: idx_a, size_bytes: 100)
        create_list(:zoekt_repository, 3, zoekt_index: idx_b, size_bytes: 200)
      end

      it 'correctly updates both indices', :freeze_time do
        consume_event(subscriber: described_class, event: event)

        expect(idx_a.reload.used_storage_bytes).to eq(300) # 3 * 100
        expect(idx_b.reload.used_storage_bytes).to eq(600) # 3 * 200
      end
    end
  end
end
