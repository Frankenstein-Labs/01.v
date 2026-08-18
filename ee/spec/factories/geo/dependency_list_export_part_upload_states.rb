# frozen_string_literal: true

FactoryBot.define do
  factory :geo_dependency_list_export_part_upload_state, class: 'Geo::DependencyListExportPartUploadState' do
    geo_dependency_list_export_part_upload

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
