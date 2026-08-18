# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_export, class: 'Vulnerabilities::Export' do
    project
    author
    association :organization, factory: :organization

    trait :csv do
      format { :csv }
    end

    trait :pdf do
      format { :pdf }
    end

    trait :with_csv_file do
      file { fixture_file_upload('ee/spec/fixtures/vulnerabilities/exports/root-security-reports_vulnerabilities_2020-03-12T1235.csv') }
    end

    trait :with_pdf_file do
      file { fixture_file_upload('ee/spec/fixtures/vulnerabilities/exports/group-project_vulnerabilities_2025-06-03T1250.pdf') }
    end

    trait :created do
      status { 'created' }
    end

    trait :running do
      status { 'running' }
      started_at { 1.minute.ago }
    end

    trait :finished do
      started_at { 1.minute.ago }
      finished_at { Time.now }
      status { 'finished' }
    end

    trait :failed do
      started_at { 1.minute.ago }
      finished_at { Time.now }
      status { 'failed' }
    end

    trait :group do
      project { nil }
      group
    end

    trait :user do
      project { nil }
      group { nil }
    end
  end
end
