# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AnalyzerTypeForStatus'], feature_category: :security_asset_inventories do
  it 'exposes the base analyzer types plus the post-processing type' do
    expect(described_class.values.keys).to include(*GitlabSchema.types['AnalyzerTypeEnum'].values.keys)
    expect(described_class.values.keys).to include('DEPENDENCY_SCANNING_POST_PROCESSING')
  end

  it 'keeps the post-processing type out of the base AnalyzerTypeEnum' do
    # dependency_scanning_post_processing has no column in security_inventory_filters, so it must stay out of
    # AnalyzerTypeEnum (used by AnalyzerFilterInput) and remain non-filterable in the inventory.
    expect(GitlabSchema.types['AnalyzerTypeEnum'].values.keys)
      .not_to include('DEPENDENCY_SCANNING_POST_PROCESSING')
  end
end
