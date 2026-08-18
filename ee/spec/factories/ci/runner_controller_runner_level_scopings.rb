# frozen_string_literal: true

FactoryBot.define do
  factory :ci_runner_controller_runner_level_scoping, class: 'Ci::RunnerControllerRunnerLevelScoping' do
    runner_controller { association :ci_runner_controller }
    runner { association :ci_runner }
  end
end
