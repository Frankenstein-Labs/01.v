# frozen_string_literal: true

FactoryBot.define do
  factory :geo_organization_detail_upload_registry, class: 'Geo::OrganizationDetailUploadRegistry' do
    association(:organization_detail_upload, factory: :geo_organization_detail_upload)
    state { Geo::OrganizationDetailUploadRegistry.state_value(:pending) }

    trait :synced do
      state { Geo::OrganizationDetailUploadRegistry.state_value(:synced) }
      last_synced_at { 5.days.ago }
    end

    trait :failed do
      state { Geo::OrganizationDetailUploadRegistry.state_value(:failed) }
      last_synced_at { 1.day.ago }
      retry_count { 2 }
      retry_at { 2.hours.from_now }
      last_sync_failure { 'Random error' }
    end

    trait :started do
      state { Geo::OrganizationDetailUploadRegistry.state_value(:started) }
      last_synced_at { 1.day.ago }
      retry_count { 0 }
    end

    trait :verification_succeeded do
      synced
      verification_checksum { 'e079a831cab27bcda7d81cd9b48296d0c3dd92ef' }
      verification_state { Geo::OrganizationDetailUploadRegistry.verification_state_value(:verification_succeeded) }
      verified_at { 5.days.ago }
    end

    trait :verification_failed do
      synced
      verification_failure { 'Could not calculate the checksum' }
      verification_state { Geo::OrganizationDetailUploadRegistry.verification_state_value(:verification_failed) }
      verification_retry_count { 1 }
      verification_retry_at { 2.hours.from_now }
    end
  end
end
