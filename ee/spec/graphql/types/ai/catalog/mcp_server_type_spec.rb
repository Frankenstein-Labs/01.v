# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::McpServerType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogMcpServer')
  end

  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_mcp_server) }

  it 'has expected fields' do
    expected_fields = %w[
      id
      name
      description
      url
      homepage_url
      transport
      auth_type
      oauth_client_id
      created_at
      updated_at
      organization
      current_user_connected
      block_status
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
