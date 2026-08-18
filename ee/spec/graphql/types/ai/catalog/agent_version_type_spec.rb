# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::AgentVersionType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogAgentVersion')
  end

  it 'implements the correct interface' do
    expect(described_class.interfaces).to include(Types::Ai::Catalog::VersionInterface)
  end

  it 'has the expected fields' do
    expected_fields = %w[
      system_prompt
      tools
      mcp_servers
      mcp_tools
      user_prompt
    ]

    expect(described_class.own_fields.size).to eq(expected_fields.size)
    expect(described_class).to include_graphql_fields(*expected_fields)
  end

  describe 'mcp_tools field' do
    subject(:mcp_tools_field) { described_class.fields['mcpTools'] }

    it 'is a nullable list of non-null strings' do
      expect(mcp_tools_field.type.to_type_signature).to eq('[String!]')
    end
  end

  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_item) }
end
