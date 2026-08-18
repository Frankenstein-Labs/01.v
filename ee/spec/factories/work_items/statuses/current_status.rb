# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_current_status, class: 'WorkItems::Statuses::CurrentStatus' do
    association :work_item
    system_defined

    trait :system_defined do
      system_defined_status_id { 1 }
    end

    trait :custom do
      system_defined_status_id { nil }
      association :custom_status, factory: :work_item_custom_status
    end
  end
end
