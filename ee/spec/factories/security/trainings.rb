# frozen_string_literal: true

FactoryBot.define do
  factory :security_training, class: 'Security::Training' do
    project
    training_provider_id { 1 }

    trait :primary do
      is_primary { true }
    end

    trait :kontra do
      training_provider_id { 1 }
    end

    trait :secure_code_warrior do
      training_provider_id { 2 }
    end
  end
end
