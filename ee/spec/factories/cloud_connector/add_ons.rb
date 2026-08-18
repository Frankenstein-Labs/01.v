# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_add_on, class: 'Gitlab::CloudConnector::DataModel::AddOn' do
    initialize_with { new(**attributes) }

    name { 'duo_pro' }
    description { 'GitLab Duo Pro' }
  end
end
