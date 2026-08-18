# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PackageMetadata::AdvisoryType, feature_category: :software_composition_analysis do
  include GraphqlHelpers

  specify { expect(described_class.graphql_name).to eq('PackageMetadataAdvisory') }

  it 'has the expected fields' do
    expected_fields = %w[
      advisory_xid
      created_at
      cve
      cvss_v2
      cvss_v3
      description
      id
      identifiers
      published_date
      source_xid
      title
      updated_at
      urls
    ]

    expect(described_class).to have_graphql_fields(*expected_fields)
  end

  describe 'source_xid field' do
    it 'returns the correct enum type' do
      expect(described_class.fields['sourceXid'])
        .to have_non_null_graphql_type(Types::PackageMetadata::AdvisorySourceEnum)
    end
  end
end
