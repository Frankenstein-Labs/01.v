# frozen_string_literal: true

FactoryBot.define do
  factory :group_secret_rotation_info, class: 'SecretsManagement::GroupSecretRotationInfo' do
    group
    sequence(:secret_name) { |n| "SECRET_#{n}" }
    rotation_interval_days { 30 }
    next_reminder_at { 30.days.from_now }
    secret_metadata_version { 1 }
  end
end
