# frozen_string_literal: true

FactoryBot.define do
  factory :project_secrets_manager, class: 'SecretsManagement::ProjectSecretsManager' do
    project

    SecretsManagement::ProjectSecretsManager::STATUSES.each_key do |k|
      trait k do
        status { SecretsManagement::ProjectSecretsManager::STATUSES[k] }
      end
    end
  end
end
