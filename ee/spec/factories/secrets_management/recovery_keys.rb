# frozen_string_literal: true

FactoryBot.define do
  factory :sm_recovery_key, class: 'SecretsManagement::RecoveryKey' do
    key { "secret_value" }
    active { false }
  end
end
