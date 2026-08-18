# frozen_string_literal: true

FactoryBot.define do
  factory :group_secrets_manager_maintenance_task,
    class: 'SecretsManagement::GroupSecretsManagerMaintenanceTask' do
    user
    group
    root_namespace_id { group&.root_ancestor&.id }
    organization_id { group&.organization_id }

    action { :provision }
    last_processed_at { Time.zone.now }
    retry_count { 0 }

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
