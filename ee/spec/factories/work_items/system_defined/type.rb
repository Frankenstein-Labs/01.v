# frozen_string_literal: true

FactoryBot.modify do
  factory :work_item_system_defined_type do
    trait :epic do
      id { 8 }
      base_type { 'epic' }
    end

    trait :objective do
      id { 6 }
      base_type { 'objective' }
    end

    trait :key_result do
      id { 7 }
      base_type { 'key_result' }
    end

    trait :requirement do
      id { 4 }
      base_type { 'requirement' }
    end

    trait :test_case do
      id { 3 }
      base_type { 'test_case' }
    end
  end
end
