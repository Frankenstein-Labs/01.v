# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiCatalogItemsSort'], feature_category: :workflow_catalog do
  it { expect(described_class.graphql_name).to eq('AiCatalogItemsSort') }

  it 'exposes all the sort values' do
    expect(described_class.values.keys).to contain_exactly(
      'CATALOG_PRIORITY',
      'STAR_COUNT_ASC',
      'STAR_COUNT_DESC',
      'USAGE_COUNT_DESC',
      'USAGE_COUNT_ASC'
    )
  end
end
