# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_system_defined_status, class: 'WorkItems::Statuses::SystemDefined::Status' do
    skip_create
    to_do

    initialize_with do
      WorkItems::Statuses::SystemDefined::Status.find(attributes[:id] || 1)
    end

    trait :to_do do
      id { 1 }
      category { :to_do }
    end

    trait :in_progress do
      id { 2 }
      category { :in_progress }
    end

    trait :done do
      id { 3 }
      category { :done }
    end

    trait :wont_do do
      id { 4 }
      category { :canceled }
    end

    trait :duplicate do
      id { 5 }
      category { :canceled }
    end
  end
end
