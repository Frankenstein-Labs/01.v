# frozen_string_literal: true

FactoryBot.define do
  factory :cd_environment, class: 'Cd::Environment' do
    organization
    sequence(:name) { |n| "environment-#{n}" }
    tier { :development }

    trait :with_description do
      description { 'A deployment environment' }
    end

    trait :development do
      tier { :development }
    end

    trait :qa do
      tier { :qa }
    end

    trait :staging do
      tier { :staging }
    end

    trait :production do
      tier { :production }
    end
  end
end
