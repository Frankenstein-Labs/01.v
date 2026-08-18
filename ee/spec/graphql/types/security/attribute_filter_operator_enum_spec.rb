# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::AttributeFilterOperatorEnum, feature_category: :security_asset_inventories do
  specify { expect(described_class.graphql_name).to eq('AttributeFilterOperator') }

  it 'exposes all the existing attribute filter operators' do
    expect(described_class.values.keys).to match_array(
      %w[
        IS_ONE_OF
        IS_NOT_ONE_OF
      ]
    )
  end
end
