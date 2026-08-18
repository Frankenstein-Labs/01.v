# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CiCatalogResourceProjectUsageSort'], feature_category: :pipeline_composition do
  it { expect(described_class.graphql_name).to eq('CiCatalogResourceProjectUsageSort') }

  it 'exposes all the project usage sort orders' do
    expect(described_class.values.keys).to match_array(
      %w[
        OLDEST_VERSION_ASC OLDEST_VERSION_DESC
        VERSION_ASC VERSION_DESC
        LAST_USED_ASC LAST_USED_DESC
        PROJECT_NAME_ASC PROJECT_NAME_DESC
      ]
    )
  end
end
