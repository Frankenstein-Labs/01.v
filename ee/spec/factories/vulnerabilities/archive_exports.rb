# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_archive_export, class: 'Vulnerabilities::ArchiveExport' do
    project
    author factory: :user

    date_range { (5.days.ago..Time.zone.today) }
    format { :csv }

    trait :with_csv_file do
      file { fixture_file_upload('ee/spec/fixtures/vulnerabilities/archive_export.csv') }
    end

    trait :running do
      status { :running }
      started_at { 1.minute.ago }
    end

    trait :finished do
      with_csv_file

      status { :finished }
    end
  end
end
