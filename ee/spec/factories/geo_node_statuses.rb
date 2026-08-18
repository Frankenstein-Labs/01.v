# frozen_string_literal: true

FactoryBot.define do
  factory :geo_node_status do
    geo_node
    storage_shards { StorageShard.all }

    trait :healthy do
      status_message { nil }
      projects_count { 10 }
      repositories_count { 10 }
      repositories_checked_failed_count { 1 }
      last_event_id { 2 }
      last_event_timestamp { Time.now.to_i }
      cursor_last_event_id { 1 }
      cursor_last_event_timestamp { Time.now.to_i }
      last_successful_status_check_timestamp { 2.minutes.ago }
      version { Gitlab::VERSION }
      revision { Gitlab.revision }
      container_repositories_replication_enabled { false }

      GeoNodeStatus.replicator_class_status_fields.each do |field|
        send(field) { rand(10000) }
      end

      Geo::SecondaryUsageData::PAYLOAD_COUNT_FIELDS.each do |field|
        send(field) { rand(10000) }
      end
    end

    trait :replicated_and_verified do
      repositories_checked_failed_count { 0 }
      repositories_checked_count { 10 }
      replication_slots_used_count { 10 }

      repositories_count { 10 }
      replication_slots_count { 10 }

      GeoNodeStatus.replicator_class_status_fields.each do |field|
        send(field) { 10 }
      end
    end

    trait :unhealthy do
      status_message { "Could not connect to Geo node - HTTP Status Code: 401 Unauthorized\nTest" }
    end
  end
end
