# frozen_string_literal: true

FactoryBot.define do
  factory :virtual_registries_cleanup_policy, class: 'VirtualRegistries::Cleanup::Policy' do
    group
    keep_n_days_after_download { 30 }
    cadence { 7 }
    enabled { false }
    notify_on_success { false }
    notify_on_failure { false }
    status { :scheduled }
    last_run_deleted_entries_count { 0 }
    last_run_deleted_size { 0 }
    last_run_detailed_metrics { {} }

    trait :enabled do
      enabled { true }
    end

    trait :with_metrics do
      last_run_detailed_metrics do
        {
          'maven' => {
            'deleted_entries_count' => 100,
            'deleted_size' => 2048
          }
        }
      end
    end
  end
end
