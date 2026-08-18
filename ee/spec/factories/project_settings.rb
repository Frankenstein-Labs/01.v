# frozen_string_literal: true

FactoryBot.modify do
  factory :project_setting do
    trait :has_vulnerabilities do
      has_vulnerabilities { true }
    end

    trait :with_product_analytics_configured do
      product_analytics_configurator_connection_string { 'http://test.com' }
      product_analytics_data_collector_host { 'http://test.net' }
      cube_api_base_url { 'https://cube.base.url.com' }
      cube_api_key { 'afakeapikey' }
    end
  end
end
