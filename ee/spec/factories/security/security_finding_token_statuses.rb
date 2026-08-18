# frozen_string_literal: true

FactoryBot.define do
  factory :security_finding_token_status, class: 'Security::FindingTokenStatus' do
    association :security_finding, factory: :security_finding

    status { :active }
    last_verified_at { Time.current }

    trait :with_secret_detection_finding do
      association :security_finding, factory: [:security_finding], strategy: :create
    end

    trait :inactive do
      status { :inactive }
    end

    trait :unknown do
      status { :unknown }
    end
  end
end
