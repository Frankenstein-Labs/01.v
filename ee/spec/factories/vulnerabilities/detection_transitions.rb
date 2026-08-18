# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_detection_transition, class: 'Vulnerabilities::DetectionTransition' do
    project
    finding { association(:vulnerabilities_finding) }
    detected { true }

    trait :detected do
      detected { true }
    end

    trait :not_detected do
      detected { false }
    end
  end
end
