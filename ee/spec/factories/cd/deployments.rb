# frozen_string_literal: true

FactoryBot.define do
  factory :cd_deployment, class: 'Cd::Deployment' do
    service { association(:cd_service) }
    rollout_environment { association(:cd_rollout_environment) }
    state { :pending }
  end
end
