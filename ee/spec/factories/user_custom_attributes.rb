# frozen_string_literal: true

FactoryBot.modify do
  factory :user_custom_attribute do
    trait :assumed_high_risk_reason do
      key { IdentityVerification::UserRiskProfile::ASSUMED_HIGH_RISK_ATTR_KEY }
      value { 'reason' }
    end
  end
end
