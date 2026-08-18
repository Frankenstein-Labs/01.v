# frozen_string_literal: true

FactoryBot.define do
  factory :ci_runner_controller, class: 'Ci::RunnerController' do
    description { "Controller for managing runner" }
    state { :disabled }

    trait :enabled do
      state { :enabled }
    end

    trait :dry_run do
      state { :dry_run }
    end
  end
end
