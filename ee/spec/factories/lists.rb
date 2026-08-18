# frozen_string_literal: true

FactoryBot.define do
  factory :user_list, parent: :list do
    list_type { :assignee }
    label { nil }
    user
  end

  factory :milestone_list, parent: :list do
    list_type { :milestone }
    label { nil }
    milestone
  end

  factory :iteration_list, parent: :list do
    list_type { :iteration }
    label { nil }
    iteration
  end

  factory :status_list, parent: :list do
    list_type { :status }
    with_system_defined_status

    trait :with_system_defined_status do
      association :system_defined_status, factory: :work_item_system_defined_status
    end

    trait :with_custom_status do
      system_defined_status { nil }
      association :custom_status, factory: :work_item_custom_status
    end
  end
end
