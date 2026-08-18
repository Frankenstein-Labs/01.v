# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerabilities_merge_request_link, class: 'Vulnerabilities::MergeRequestLink' do
    vulnerability
    merge_request
    readiness_score { nil }

    transient do
      project { nil }
    end

    trait :with_readiness_score do
      readiness_score { 0.8 }
    end
  end
end
