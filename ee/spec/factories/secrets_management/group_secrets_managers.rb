# frozen_string_literal: true

FactoryBot.define do
  factory :group_secrets_manager, class: 'SecretsManagement::GroupSecretsManager' do
    group

    SecretsManagement::GroupSecretsManager::STATUSES.each_key do |k|
      trait k do
        status { SecretsManagement::GroupSecretsManager::STATUSES[k] }
      end
    end
  end
end
