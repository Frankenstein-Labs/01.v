# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Search::Blob::LineType, feature_category: :global_search do
  it { expect(described_class.graphql_name).to eq('SearchBlobLine') }

  it { expect(described_class).to have_graphql_fields(:highlights, :line_number, :text) }
end
