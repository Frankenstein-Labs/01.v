# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ::Search::Elastic::Sorts::Base, feature_category: :global_search do
  let(:query_hash) { {} }

  describe '#sort_by' do
    using RSpec::Parameterized::TableSyntax

    subject(:sort_by) { described_class.sort_by(query_hash: query_hash, options: options) }

    where(:doc_type, :order_by, :sort, :expected) do
      'merge_request' | nil | nil | { sort: {} }
      'merge_request' | 'created_at' | 'asc' | { sort: { created_at: { order: 'asc' } } }
      'merge_request' | 'created_at' | 'desc' | { sort: { created_at: { order: 'desc' } } }
      'merge_request' | 'updated_at' | 'asc' | { sort: { updated_at: { order: 'asc' } } }
      'merge_request' | 'updated_at' | 'desc' | { sort: { updated_at: { order: 'desc' } } }
      'merge_request' | nil | 'created_asc' | { sort: { created_at: { order: 'asc' } } }
      'merge_request' | nil | 'created_desc' | { sort: { created_at: { order: 'desc' } } }
      'merge_request' | nil | 'updated_asc' | { sort: { updated_at: { order: 'asc' } } }
      'merge_request' | nil | 'updated_desc' | { sort: { updated_at: { order: 'desc' } } }
      'merge_request' | 'weight' | 'asc' | { sort: {} }
      'merge_request' | 'health_status' | 'desc' | { sort: {} }
      'merge_request' | 'popularity' | 'asc' | { sort: {} }
      'merge_request' | nil | 'due_date_asc' | { sort: {} }
    end

    with_them do
      let(:options) { { doc_type: doc_type, order_by: order_by, sort: sort } }

      it { is_expected.to eq(expected) }
    end
  end
end
