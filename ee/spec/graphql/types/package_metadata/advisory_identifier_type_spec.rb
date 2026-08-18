# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PackageMetadata::AdvisoryIdentifierType, feature_category: :software_composition_analysis do
  include GraphqlHelpers

  specify { expect(described_class.graphql_name).to eq('PackageMetadataAdvisoryIdentifier') }

  it 'has the expected fields' do
    expected_fields = %w[
      type
      name
      value
      url
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
