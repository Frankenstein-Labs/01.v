# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_index, class: '::Search::Zoekt::Index' do
    zoekt_enabled_namespace { association(:zoekt_enabled_namespace) }
    node { association(:zoekt_node) }
    replica { association(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
    namespace_id { zoekt_enabled_namespace.root_namespace_id }
    reserved_storage_bytes { 100 }

    trait :overprovisioned do
      after(:build) do |index|
        index.used_storage_bytes = (index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_IDEAL_PERCENT_USED) - 1
        index.watermark_level = Search::Zoekt::Index.watermark_levels[:overprovisioned]
      end
    end

    trait :healthy do
      after(:build) do |index|
        index.used_storage_bytes = (index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_LOW_WATERMARK) - 1
        index.watermark_level = Search::Zoekt::Index.watermark_levels[:healthy]
      end
    end

    trait :low_watermark_exceeded do
      after(:build) do |index|
        index.used_storage_bytes = (index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_HIGH_WATERMARK) - 1
        index.watermark_level = Search::Zoekt::Index.watermark_levels[:low_watermark_exceeded]
      end
    end

    trait :high_watermark_exceeded do
      after(:build) do |index|
        index.used_storage_bytes = (index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_HIGH_WATERMARK) + 1
        index.watermark_level = Search::Zoekt::Index.watermark_levels[:high_watermark_exceeded]
      end
    end

    trait :critical_watermark_exceeded do
      after(:build) do |index|
        index.used_storage_bytes = (index.reserved_storage_bytes * Search::Zoekt::Index::STORAGE_CRITICAL_WATERMARK) + 1
        index.watermark_level = Search::Zoekt::Index.watermark_levels[:critical_watermark_exceeded]
      end
    end
  end

  trait :ready do
    state { ::Search::Zoekt::Index.state_value(:ready) }
  end

  trait :pending_deletion do
    state { ::Search::Zoekt::Index.state_value(:pending_deletion) }
  end

  trait :pending_eviction do
    state { ::Search::Zoekt::Index.state_value(:pending_eviction) }
  end

  trait :negative_reserved_storage_bytes do
    reserved_storage_bytes { -100 }
  end

  trait :stale_used_storage_bytes_updated_at do
    used_storage_bytes_updated_at { 4.minutes.ago }
    last_indexed_at { Time.now }
  end

  trait :latest_used_storage_bytes do
    used_storage_bytes_updated_at { Time.now }
    last_indexed_at { 4.minutes.ago }
  end
end
