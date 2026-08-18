# frozen_string_literal: true

FactoryBot.define do
  factory :cd_rollout_step, class: 'Cd::RolloutStep' do
    rollout { association(:cd_rollout) }
    sequence(:path, &:to_s)
    step_type { 'com.gitlab.cd.steps.wait' }
    state { :pending }
  end
end
