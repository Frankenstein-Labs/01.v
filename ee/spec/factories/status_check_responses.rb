# frozen_string_literal: true

FactoryBot.define do
  factory :status_check_response, class: 'MergeRequests::StatusCheckResponse' do
    merge_request
    external_status_check
    sha { 'aabccddee' }
    status { 'passed' }

    trait(:pending) { status { 'pending' } }

    trait(:old) do
      created_at { 1.day.ago }
    end

    trait(:recent_retried) do
      created_at { 1.day.ago }
      retried_at { 1.minute.ago }
    end

    trait(:old_retried) do
      created_at { 1.day.ago }
      retried_at { 1.day.ago }
    end

    factory :old_pending_status_check_response, traits: [:pending, :old]
    factory :old_passed_status_check_response, traits: [:passed, :old]
    factory :old_failed_status_check_response, traits: [:failed, :old]
    factory :old_retried_pending_status_check_response, traits: [:pending, :old_retried]
    factory :recent_retried_pending_status_check_response, traits: [:pending, :recent_retried]
  end
end
