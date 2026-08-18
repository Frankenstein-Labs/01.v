# frozen_string_literal: true

FactoryBot.define do
  factory :geo_ci_job_artifact_verification_summary, class: '::Geo::CiJobArtifactVerificationSummary' do
    sequence(:bucket_number) { |n| n }
    state { :clean }
    state_changed_at { Time.current }
    total_count { 0 }
    verified_count { 0 }
    failed_count { 0 }

    trait :dirty do
      state { :dirty }
      state_changed_at { Time.current }
    end

    trait :calculating do
      state { :calculating }
      state_changed_at { Time.current }
    end

    trait :with_counts do
      total_count { 100 }
      verified_count { 90 }
      failed_count { 5 }
      last_calculated_at { Time.current }
    end
  end
end
