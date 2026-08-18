# frozen_string_literal: true

FactoryBot.define do
  factory :cloud_connector_access, class: 'CloudConnector::Access' do
    catalog do
      Gitlab::CloudConnector::DataModel.load_all.except(:services)
    end

    trait :current do
      updated_at { Time.current }
    end

    trait :stale do
      updated_at { Time.current - ::CloudConnector::Access::STALE_PERIOD - 1.minute }
    end
  end
end
