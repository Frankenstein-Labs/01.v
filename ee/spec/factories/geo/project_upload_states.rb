# frozen_string_literal: true

FactoryBot.define do
  factory :geo_project_upload_state, class: 'Geo::ProjectUploadState' do
    project_upload

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
