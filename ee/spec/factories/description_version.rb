# frozen_string_literal: true

FactoryBot.modify do
  factory :description_version do
    trait :epic do
      association :epic
    end
  end
end
