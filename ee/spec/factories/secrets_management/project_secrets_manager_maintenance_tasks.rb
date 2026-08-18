# frozen_string_literal: true

FactoryBot.define do
  factory :project_secrets_manager_maintenance_task,
    class: 'SecretsManagement::ProjectSecretsManagerMaintenanceTask' do
    user
    project

    action { :provision }
    last_processed_at { Time.zone.now }
    retry_count { 0 }
    project_id { project&.id }
    organization_id { project&.organization_id }
    root_namespace_id { project&.root_ancestor&.id }

    trait :provision do
      action { :provision }
    end

    trait :deprovision do
      action { :deprovision }
    end

    trait :processing do
      last_processed_at { 1.minute.ago }
    end

    trait :stale do
      last_processed_at { 7.minutes.ago }
    end
  end
end
