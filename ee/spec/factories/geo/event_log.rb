# frozen_string_literal: true

FactoryBot.define do
  factory :geo_event_log, class: 'Geo::EventLog' do
    trait :cache_invalidation_event do
      cache_invalidation_event factory: :geo_cache_invalidation_event
    end

    trait :geo_event do
      geo_event factory: :geo_event
    end
  end

  factory :geo_cache_invalidation_event, class: 'Geo::CacheInvalidationEvent' do
    sequence(:key) { |n| "cache-key-#{n}" }
  end
end
