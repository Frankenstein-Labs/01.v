# frozen_string_literal: true

FactoryBot.define do
  factory :geo_user_permission_export_upload_upload_state, class: 'Geo::UserPermissionExportUploadUploadState' do
    user_permission_export_upload_upload

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
