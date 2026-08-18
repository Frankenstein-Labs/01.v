# frozen_string_literal: true

FactoryBot.define do
  factory :cd_service_environment_health, class: 'Cd::ServiceEnvironmentHealth' do
    service { association(:cd_service) }
    environment { association(:cd_environment) }
    health { :unknown }
    observed_at { Time.current }
  end
end
