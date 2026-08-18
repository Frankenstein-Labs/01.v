# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_node, class: '::Search::Zoekt::Node' do
    index_base_url { "http://#{SecureRandom.hex(4)}.example.com" }
    search_base_url { "http://#{SecureRandom.hex(4)}.example.com" }
    uuid { SecureRandom.uuid }
    last_seen_at { Time.zone.now }
    used_bytes { 10 }
    total_bytes { 100 }

    sequence(:metadata) do |n|
      { name: "zoekt-#{n}" }
    end

    trait :enough_free_space do
      total_bytes { 10.gigabytes }
    end

    trait :offline do
      last_seen_at { (Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD + 1.day).ago }
    end

    trait :lost do
      last_seen_at { 1.year.ago }
    end

    trait :not_enough_free_space do
      total_bytes { 100_000_000 }
      used_bytes { 90_000_000 }
    end

    trait :for_search do
      services { [::Search::Zoekt::Node::SERVICES[:zoekt]] }
    end

    trait :knowledge_graph do
      services { [::Search::Zoekt::Node::SERVICES[:knowledge_graph]] }
    end

    transient do
      healthy_process_metrics do
        {
          'mmap_current' => 100,
          'mmap_max' => 1000,
          'restarts_1m' => 0,
          'restarts_5m' => 0,
          'restarts_15m' => 0,
          'rss_bytes' => 268_435_456,
          'uptime_seconds' => 3600
        }
      end

      unhealthy_process_metrics do
        healthy_process_metrics.merge('restarts_15m' => 5)
      end
    end

    trait :healthy_process do
      webserver_last_seen_at { Time.zone.now }

      metadata do
        {
          'name' => "zoekt-#{SecureRandom.hex(4)}",
          'version' => '1.16.0',
          'process_health' => {
            'indexer' => healthy_process_metrics,
            'webserver' => healthy_process_metrics
          }
        }
      end
    end

    trait :unhealthy_process do
      webserver_last_seen_at { Time.zone.now }

      metadata do
        {
          'name' => "zoekt-#{SecureRandom.hex(4)}",
          'version' => '1.16.0',
          'process_health' => {
            'indexer' => unhealthy_process_metrics,
            'webserver' => healthy_process_metrics
          }
        }
      end
    end

    # Watermark level traits based on storage usage
    # These create nodes that fall into specific watermark categories
    trait :watermark_critical do
      total_bytes { 1_000_000_000 } # 1GB
      used_bytes { (total_bytes * (::Search::Zoekt::Node::WATERMARK_LIMIT_CRITICAL + 0.01)).to_i }
    end

    trait :watermark_high do
      total_bytes { 1_000_000_000 } # 1GB
      # High but not critical (between high and critical thresholds)
      used_bytes do
        high_limit = ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH
        critical_limit = ::Search::Zoekt::Node::WATERMARK_LIMIT_CRITICAL
        (total_bytes * ((high_limit + critical_limit) / 2)).to_i
      end
    end

    trait :watermark_low do
      total_bytes { 1_000_000_000 } # 1GB
      # Low but not high (between low and high thresholds)
      used_bytes do
        low_limit = ::Search::Zoekt::Node::WATERMARK_LIMIT_LOW
        high_limit = ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH
        (total_bytes * ((low_limit + high_limit) / 2)).to_i
      end
    end

    trait :watermark_normal do
      total_bytes { 1_000_000_000 } # 1GB
      used_bytes { (total_bytes * (::Search::Zoekt::Node::WATERMARK_LIMIT_LOW - 0.01)).to_i }
    end
  end
end
