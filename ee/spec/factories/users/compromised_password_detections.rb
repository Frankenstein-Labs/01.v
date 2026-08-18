# frozen_string_literal: true

FactoryBot.define do
  factory :compromised_password_detection, class: 'Users::CompromisedPasswordDetection' do
    user

    trait :resolved do
      resolved_at { Time.zone.now }
    end
  end
end
