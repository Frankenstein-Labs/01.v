# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ai::Catalog::FlowConfigTypeEnum, feature_category: :workflow_catalog do
  specify { expect(described_class.graphql_name).to eq('AiCatalogFlowConfigType') }

  it 'exposes the expected flow config types' do
    expect(described_class.values.keys).to contain_exactly('CHAT')
  end
end
