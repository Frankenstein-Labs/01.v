# frozen_string_literal: true

FactoryBot.define do
  factory :geo_dependency_list_export_upload_registry, class: 'Geo::DependencyListExportUploadRegistry' do
    association(:dependency_list_export_upload, factory: :geo_dependency_list_export_upload)
    state { Geo::DependencyListExportUploadRegistry.state_value(:pending) }

    trait :synced do
      state { Geo::DependencyListExportUploadRegistry.state_value(:synced) }
      last_synced_at { 5.days.ago }
    end

    trait :failed do
      state { Geo::DependencyListExportUploadRegistry.state_value(:failed) }
      last_synced_at { 1.day.ago }
      retry_count { 2 }
      retry_at { 2.hours.from_now }
      last_sync_failure { 'Random error' }
    end

    trait :started do
      state { Geo::DependencyListExportUploadRegistry.state_value(:started) }
      last_synced_at { 1.day.ago }
      retry_count { 0 }
    end

    trait :verification_succeeded do
      synced
      verification_checksum { 'e079a831cab27bcda7d81cd9b48296d0c3dd92ef' }
      verification_state { Geo::DependencyListExportUploadRegistry.verification_state_value(:verification_succeeded) }
      verified_at { 5.days.ago }
    end

    trait :verification_failed do
      synced
      verification_failure { 'Could not calculate the checksum' }
      verification_state { Geo::DependencyListExportUploadRegistry.verification_state_value(:verification_failed) }
      verification_retry_count { 1 }
      verification_retry_at { 2.hours.from_now }
    end
  end
end
