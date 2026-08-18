# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ai::Catalog::McpServer::Update, feature_category: :workflow_catalog do
  include GraphqlHelpers

  subject(:mutation) { described_class }

  it { is_expected.to have_graphql_name('AiCatalogMcpServerUpdate') }

  it { is_expected.to have_graphql_fields(:mcp_server, :errors, :client_mutation_id) }

  it 'has expected arguments' do
    is_expected.to have_graphql_arguments(
      :id,
      :name,
      :description,
      :url,
      :homepage_url,
      :transport,
      :auth_type,
      :oauth_client_id,
      :oauth_client_secret,
      :client_mutation_id
    )
  end
end
