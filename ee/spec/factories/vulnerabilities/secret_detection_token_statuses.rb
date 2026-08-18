# frozen_string_literal: true

FactoryBot.define do
  factory :finding_token_status, class: 'Vulnerabilities::FindingTokenStatus' do
    association :finding, factory: :vulnerabilities_finding, strategy: :create

    vulnerability_occurrence_id { finding.id }
    last_verified_at { Time.current }

    status { :active }

    trait :with_secret_detection_finding do
      association :finding, factory: [:vulnerabilities_finding, :with_secret_detection], strategy: :create
    end

    trait :inactive do
      status { :inactive }
    end

    trait :unknown do
      status { :unknown }
    end
  end
end
