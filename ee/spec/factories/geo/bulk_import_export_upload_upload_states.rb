# frozen_string_literal: true

FactoryBot.define do
  factory :geo_bulk_import_export_upload_upload_state, class: 'Geo::BulkImportExportUploadUploadState' do
    bulk_import_export_upload_upload

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
