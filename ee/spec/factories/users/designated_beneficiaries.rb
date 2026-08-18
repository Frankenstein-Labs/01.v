# frozen_string_literal: true

FactoryBot.define do
  factory :designated_beneficiary, class: 'Users::DesignatedBeneficiary' do
    user
    name { 'John Doe' }
    email { 'john.doe@example.com' }
    type { :manager }

    trait :manager do
      type { :manager }
    end

    trait :successor do
      type { :successor }
      relationship { 'Spouse' }
    end

    trait :without_email do
      email { nil }
    end

    trait :without_relationship do
      relationship { nil }
    end
  end
end
