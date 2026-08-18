# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::PackageMetadata::AdvisorySourceEnum, feature_category: :software_composition_analysis do
  it { expect(described_class.graphql_name).to eq('PackageMetadataAdvisorySource') }

  it 'includes the known advisory sources' do
    expect(described_class.values.keys).to include('GLAD', 'TRIVY_DB')
    expect(described_class.values['GLAD'].value).to eq('glad')
    expect(described_class.values['TRIVY_DB'].value).to eq('trivy-db')
  end

  it 'exposes all advisory sources from the backing enum' do
    backing_enum = ::Enums::PackageMetadata.advisory_sources
    graphql_enum = described_class.values

    # Verify each backing enum entry is exposed in GraphQL with the string key as value
    # (matching what Rails enum returns when accessing the attribute)
    backing_enum.each_key do |source|
      graphql_key = source.underscore.upcase
      expect(graphql_enum[graphql_key]).to be_present
      expect(graphql_enum[graphql_key].value).to eq(source.to_s)
    end

    # Verify no extra values were added to GraphQL enum
    expected_keys = backing_enum.keys.map { |k| k.underscore.upcase }
    expect(graphql_enum.keys).to match_array(expected_keys)
  end
end
