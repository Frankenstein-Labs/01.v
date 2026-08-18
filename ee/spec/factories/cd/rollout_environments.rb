# frozen_string_literal: true

FactoryBot.define do
  factory :cd_rollout_environment, class: 'Cd::RolloutEnvironment' do
    rollout { association(:cd_rollout) }
    environment { association(:cd_environment) }
    driver_binding { association(:cd_environment_driver_binding, environment: environment) }
    sequence(:position) { |n| n }
    state { :pending }
  end
end
