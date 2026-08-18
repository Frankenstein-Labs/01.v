# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Ci::Catalog::Resources::ComponentUsageDetailType, feature_category: :pipeline_composition do
  specify { expect(described_class.graphql_name).to eq('CiCatalogResourceComponentUsageDetail') }

  it 'exposes the expected fields' do
    expected_fields = %i[
      component
      version
      last_used_date
      outdated
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
