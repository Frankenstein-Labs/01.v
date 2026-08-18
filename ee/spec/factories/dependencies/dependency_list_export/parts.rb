# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_list_export_part, class: 'Dependencies::DependencyListExport::Part' do
    dependency_list_export
    organization

    start_id { 0 }
    end_id { 1 }

    trait :exported do
      file { fixture_file_upload('ee/spec/fixtures/dependencies/export_part.json') }
    end
  end
end
