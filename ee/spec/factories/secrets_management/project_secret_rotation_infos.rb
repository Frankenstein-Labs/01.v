# frozen_string_literal: true

FactoryBot.define do
  factory :project_secret_rotation_info, class: 'SecretsManagement::ProjectSecretRotationInfo' do
    project
    sequence(:secret_name) { |n| "SECRET_#{n}" }
    rotation_interval_days { 30 }
    next_reminder_at { 30.days.from_now }
    secret_metadata_version { 1 }
  end
end
