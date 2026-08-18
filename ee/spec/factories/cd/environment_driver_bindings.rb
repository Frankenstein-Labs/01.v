# frozen_string_literal: true

FactoryBot.define do
  factory :cd_environment_driver_binding, class: 'Cd::EnvironmentDriverBinding' do
    environment { association(:cd_environment) }
    driver_ref { 'argo-rollouts' }
    driver_config { { 'cluster_agent_id' => '1' } }
  end
end
