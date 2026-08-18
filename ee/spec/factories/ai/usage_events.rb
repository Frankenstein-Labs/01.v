# frozen_string_literal: true

FactoryBot.define do
  factory :ai_usage_event, class: '::Ai::UsageEvent' do
    event { 'request_duo_chat_response' }
    association :user, :with_namespace
    namespace { user&.namespace }
    timestamp { Time.current }
    extras { {} }

    trait :with_unknown_event do
      after(:create) do |usage_event|
        usage_event.update_column(:event, 99)
      end
    end
  end
end
