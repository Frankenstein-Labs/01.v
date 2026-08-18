# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_custom_status, class: 'WorkItems::Statuses::Custom::Status' do
    sequence(:name) { |n| "Custom Status #{n}" }

    association :namespace
    open

    trait :triage do
      name { FFaker::Name.unique.name }
      color { '#995715' }
      category { :triage }
      converted_from_system_defined_status_identifier { nil }
    end

    trait :open do
      name { FFaker::Name.unique.name }
      color { '#737278' }
      category { :to_do }
      converted_from_system_defined_status_identifier { 1 }
    end

    trait :to_do do
      open
    end

    trait :in_progress do
      name { FFaker::Name.unique.name }
      color { '#1f75cb' }
      category { :in_progress }
      converted_from_system_defined_status_identifier { 2 }
    end

    trait :closed do
      name { FFaker::Name.unique.name }
      color { '#108548' }
      category { :done }
      converted_from_system_defined_status_identifier { 3 }
    end

    trait :done do
      closed
    end

    trait :duplicate do
      name { FFaker::Name.unique.name }
      color { '#DD2B0E' }
      category { :canceled }
      converted_from_system_defined_status_identifier { 5 }
    end

    trait :without_conversion_mapping do
      name { FFaker::Name.unique.name }
      color { '#737278' }
      category { :to_do }
      converted_from_system_defined_status_identifier { nil }
    end
  end
end
