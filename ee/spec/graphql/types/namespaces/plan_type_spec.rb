# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['NamespacePlan'], feature_category: :consumables_cost_management do
  specify { expect(described_class.graphql_name).to eq('NamespacePlan') }

  it 'has the expected fields' do
    expected_fields = %w[is_paid name title]

    expect(described_class).to include_graphql_fields(*expected_fields)
  end
end
