# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_mcp_servers_user, class: 'Ai::Catalog::McpServersUser' do
    mcp_server { association(:ai_catalog_mcp_server) }
    organization { mcp_server.organization }
    user
    token { { 'access_token' => 'token123' } }
    refresh_token { { 'refresh_token' => 'refresh_token123' } }
  end
end
