# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_export_part, class: 'Vulnerabilities::Export::Part' do
    vulnerability_export
    organization
    start_id { 1 }
    end_id { 1 }

    trait :with_csv_file do
      file { fixture_file_upload('ee/spec/fixtures/vulnerabilities/archive_export.csv') }
    end
  end
end
