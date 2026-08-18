# frozen_string_literal: true

FactoryBot.define do
  factory :geo_abuse_report_upload_state, class: 'Geo::AbuseReportUploadState' do
    abuse_report_upload

    trait :checksummed do
      verification_checksum { 'abc' }
    end

    trait :checksum_failure do
      verification_failure { 'Could not calculate the checksum' }
    end
  end
end
