# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::McpToolIconType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogMcpToolIcon')
  end

  it 'has the expected fields' do
    expected_fields = %w[src mime_type theme]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
