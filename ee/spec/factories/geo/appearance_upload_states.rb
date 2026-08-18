# frozen_string_literal: true

FactoryBot.define do
  factory :geo_appearance_upload_state, class: 'Geo::AppearanceUploadState' do
    association :appearance_upload, factory: :geo_appearance_upload

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
