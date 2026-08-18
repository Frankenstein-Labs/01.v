# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::BuiltInToolType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogBuiltInTool')
  end

  it 'has the expected fields' do
    expected_fields = %w[
      description
      id
      title
      name
    ]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
