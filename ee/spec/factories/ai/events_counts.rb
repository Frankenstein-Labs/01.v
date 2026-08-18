# frozen_string_literal: true

FactoryBot.define do
  factory :ai_events_count, class: '::Ai::EventsCount' do
    events_date { Date.current }
    association :organization
    association :namespace
    association :user
    event { Ai::EventsCount.events.keys.sample }
    total_occurrences { rand(1..50) }
  end
end
