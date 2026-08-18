# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['AiCatalogItemVisibility'], feature_category: :workflow_catalog do
  it 'exposes all visibility levels' do
    expect(described_class.values.keys).to match_array(%w[PRIVATE RESTRICTED PUBLIC])
  end
end
