# frozen_string_literal: true

FactoryBot.define do
  factory :ci_runner_controller_instance_level_scoping, class: 'Ci::RunnerControllerInstanceLevelScoping' do
    runner_controller { association :ci_runner_controller }
  end
end
