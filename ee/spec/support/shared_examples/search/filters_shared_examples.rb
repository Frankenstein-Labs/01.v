# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'does not modify the query_hash' do
  it 'does not add the filter to query_hash' do
    expect { subject }.not_to change { query_hash }
  end
end

# Tests that an Elasticsearch filter is properly added to the query hash
# while ensuring other boolean query parts remain empty. Uses match instead of eq to work
# with contain_exactly and match_array
# Requires:
#   - `subject`: returns the complete Elasticsearch query hash
#     e.g., subject(:by_assignees) { described_class.by_assignees(query_hash: query_hash, options: options) }
#   - `expected_filter`: the expected filter array structure
RSpec.shared_examples 'adds filter to query_hash' do
  it 'adds the expected filter and leaves other query parts empty' do
    expect(subject.dig(:query, :bool, :filter)).to match(expected_filter)
    expect(subject.dig(:query, :bool, :must)).to be_empty
    expect(subject.dig(:query, :bool, :must_not)).to be_empty
    expect(subject.dig(:query, :bool, :should)).to be_empty
  end
end
