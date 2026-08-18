# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_backend_service, class: 'Gitlab::CloudConnector::DataModel::BackendService' do
    initialize_with { new(**attributes) }

    name { 'ai-backend' }
    jwt_aud { 'https://ai.gitlab.com' }
  end
end
