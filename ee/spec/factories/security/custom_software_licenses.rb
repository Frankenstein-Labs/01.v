# frozen_string_literal: true

FactoryBot.define do
  factory :custom_software_license, class: 'Security::CustomSoftwareLicense' do
    sequence(:name) { |n| "CUSTOM-SOFTWARE-LICENSE-2.7/example_#{n}" }

    project
  end
end
