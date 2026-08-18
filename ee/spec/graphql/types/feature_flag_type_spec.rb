# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['FeatureFlag'], feature_category: :feature_flags do
  specify { expect(described_class.graphql_name).to eq('FeatureFlag') }

  specify { expect(described_class).to require_graphql_authorizations(:read_feature_flag) }

  it 'has specific fields' do
    fields = %i[
      id
      name
      active
      path
      reference
    ]

    expect(described_class).to have_graphql_fields(*fields)
  end
end
