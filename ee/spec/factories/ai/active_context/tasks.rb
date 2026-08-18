# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_task, class: 'Ai::ActiveContext::Task' do
    sequence(:name) { |n| "TestTask#{n}" }
    association :connection, factory: :ai_active_context_connection
    status { :pending }

    trait :in_progress do
      status { :in_progress }
      started_at { Time.current }
    end

    trait :completed do
      status { :completed }
      started_at { 1.hour.ago }
      completed_at { Time.current }
    end

    trait :failed do
      status { :failed }
      started_at { 1.hour.ago }
      retries_left { 0 }
      error_message { "Failed due to error XYZ" }
    end
  end
end
