# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiCatalogVersionBump'], feature_category: :workflow_catalog do
  it 'exposes all version bump options' do
    expect(described_class.values.keys).to match_array(
      Ai::Catalog::ItemVersion::VERSION_BUMP_OPTIONS.map { |o| o.to_s.upcase }
    )
  end
end
