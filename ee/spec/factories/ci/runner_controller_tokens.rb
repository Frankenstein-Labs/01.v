# frozen_string_literal: true

FactoryBot.define do
  factory :ci_runner_controller_token, class: 'Ci::RunnerControllerToken' do
    association :runner_controller, factory: :ci_runner_controller

    description { "Token for runner controller" }

    trait :revoked do
      status { :revoked }
    end

    trait :recently_used do
      last_used_at { 30.minutes.ago }
    end

    trait :not_recently_used do
      last_used_at { 2.hours.ago }
    end

    trait :unused do
      last_used_at { nil }
    end
  end
end
