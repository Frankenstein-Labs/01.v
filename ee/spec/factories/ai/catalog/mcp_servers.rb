# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_mcp_server, class: 'Ai::Catalog::McpServer' do
    organization { association(:common_organization) }
    created_by { association(:user) }
    sequence(:name) { |n| "MCP Server #{n}" }
    sequence(:description) { |n| "Description for MCP Server #{n}" }
    sequence(:url) { |n| "https://example.com/mcp-server-#{n}" }
    sequence(:homepage_url) { |n| "https://example.com/homepage-#{n}" }
    transport { :http }
    auth_type { :no_auth }

    trait :with_oauth do
      auth_type { :oauth }
      sequence(:oauth_client_id) { |n| "client_id_#{n}" }
      oauth_client_secret { { 'secret' => 'secret123' } }
    end
  end
end
