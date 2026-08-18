# frozen_string_literal: true

FactoryBot.define do
  factory :ai_active_context_migration, class: 'Ai::ActiveContext::Migration' do
    sequence(:version) { |n| Time.now.strftime("%Y%m%d%H%M#{n.to_s.rjust(2, '0')}") }
    association :connection, factory: :ai_active_context_connection
    status { :pending }
    metadata { { source: 'factory' } }

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
      completed_at { Time.current }
      retries_left { 0 }
      error_message { "Failed due to error XYZ" }
    end

    trait :with_metadata do
      metadata do
        {
          source_version: '20240101000000',
          target_version: '20240201000000',
          affected_records: 1000
        }
      end
    end
  end
end
