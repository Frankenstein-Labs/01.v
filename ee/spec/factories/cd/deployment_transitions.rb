# frozen_string_literal: true

FactoryBot.define do
  factory :cd_deployment_transition, class: 'Cd::DeploymentTransition' do
    deployment { association(:cd_deployment) }
    from_state { :pending }
    to_state { :deploying }
    event { 'start_deploying' }
    principal { 'user:1' }
  end
end
