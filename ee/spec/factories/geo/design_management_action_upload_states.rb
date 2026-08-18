# frozen_string_literal: true

FactoryBot.define do
  factory :geo_design_management_action_upload_state, class: 'Geo::DesignManagementActionUploadState' do
    design_management_action_upload

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
