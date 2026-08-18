# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Search::Blob::ChunkType, feature_category: :global_search do
  it { expect(described_class.graphql_name).to eq('SearchBlobChunk') }

  it { expect(described_class).to have_graphql_fields(:lines, :match_count_in_chunk) }
end
