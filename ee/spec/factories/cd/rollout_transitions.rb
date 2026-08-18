# frozen_string_literal: true

FactoryBot.define do
  factory :cd_rollout_transition, class: 'Cd::RolloutTransition' do
    rollout { association(:cd_rollout) }
    from_state { :pending }
    to_state { :in_progress }
    event { 'start' }
    principal { 'user:1' }
  end
end
