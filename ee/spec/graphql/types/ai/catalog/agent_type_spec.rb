# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::AgentType, feature_category: :workflow_catalog do
  it 'has the correct name' do
    expect(described_class.graphql_name).to eq('AiCatalogAgent')
  end

  it 'implements the correct interface' do
    expect(described_class.interfaces).to include(Types::Ai::Catalog::ItemInterface)
  end

  it 'exposes agent fields' do
    expect(described_class).to have_graphql_field(:foundational_agent_reference)
  end

  it { expect(described_class).to require_graphql_authorizations(:read_ai_catalog_item) }
end
