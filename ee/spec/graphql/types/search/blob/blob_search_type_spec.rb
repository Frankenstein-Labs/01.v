# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Search::Blob::BlobSearchType, feature_category: :global_search do
  it { expect(described_class.graphql_name).to eq('BlobSearch') }

  it 'has all the fields' do
    expected_fields = %i[durationS fileCount files matchCount perPage searchLevel searchType]
    expect(described_class).to have_graphql_fields(*expected_fields)
  end
end
