# frozen_string_literal: true

RSpec.shared_context 'with filters shared context' do
  let(:query_hash) { { query: { bool: { filter: [], must_not: [], must: [], should: [] } } } }
end
