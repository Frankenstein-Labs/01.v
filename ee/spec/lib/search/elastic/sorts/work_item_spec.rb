# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Sorts::WorkItem, feature_category: :global_search do
  let(:query_hash) { {} }

  describe '#sort_by' do
    using RSpec::Parameterized::TableSyntax

    subject(:sort_by) { described_class.sort_by(query_hash: query_hash, options: options) }

    where(:order_by, :sort, :expected) do
      nil | nil | { sort: {} }
      'created_at' | 'asc' | { sort: { created_at: { order: 'asc' } } }
      'created_at' | 'desc' | { sort: { created_at: { order: 'desc' } } }
      'updated_at' | 'asc' | { sort: { updated_at: { order: 'asc' } } }
      'updated_at' | 'desc' | { sort: { updated_at: { order: 'desc' } } }
      'popularity' | 'asc' | { sort: { upvotes: { order: 'asc' } } }
      'popularity' | 'desc' | { sort: { upvotes: { order: 'desc' } } }
      'milestone_due' | 'asc' | { sort: { milestone_due_date: { order: 'asc' } } }
      'milestone_due' | 'desc' | { sort: { milestone_due_date: { order: 'desc' } } }
      'weight' | 'asc' | { sort: { weight: { order: 'asc' } } }
      'weight' | 'desc' | { sort: { weight: { order: 'desc' } } }
      'health_status' | 'asc' | { sort: { health_status: { order: 'asc' } } }
      'health_status' | 'desc' | { sort: { health_status: { order: 'desc' } } }
      'closed_at' | 'asc' | { sort: { closed_at: { order: 'asc' } } }
      'closed_at' | 'desc' | { sort: { closed_at: { order: 'desc' } } }
      'due_date' | 'asc' | { sort: { due_date: { order: 'asc' } } }
      'due_date' | 'desc' | { sort: { due_date: { order: 'desc' } } }
      nil | 'created_asc' | { sort: { created_at: { order: 'asc' } } }
      nil | 'created_desc' | { sort: { created_at: { order: 'desc' } } }
      nil | 'updated_asc' | { sort: { updated_at: { order: 'asc' } } }
      nil | 'updated_desc' | { sort: { updated_at: { order: 'desc' } } }
      nil | 'popularity_asc' | { sort: { upvotes: { order: 'asc' } } }
      nil | 'popularity_desc' | { sort: { upvotes: { order: 'desc' } } }
      nil | 'milestone_due_asc' | { sort: { milestone_due_date: { order: 'asc' } } }
      nil | 'milestone_due_desc' | { sort: { milestone_due_date: { order: 'desc' } } }
      nil | 'weight_asc' | { sort: { weight: { order: 'asc' } } }
      nil | 'weight_desc' | { sort: { weight: { order: 'desc' } } }
      nil | 'health_status_asc' | { sort: { health_status: { order: 'asc' } } }
      nil | 'health_status_desc' | { sort: { health_status: { order: 'desc' } } }
      nil | 'closed_at_asc' | { sort: { closed_at: { order: 'asc' } } }
      nil | 'closed_at_desc' | { sort: { closed_at: { order: 'desc' } } }
      nil | 'due_date_asc' | { sort: { due_date: { order: 'asc' } } }
      nil | 'due_date_desc' | { sort: { due_date: { order: 'desc' } } }
    end

    with_them do
      let(:options) { { order_by: order_by, sort: sort } }

      it { is_expected.to eq(expected) }
    end
  end

  describe 'SORT_MAPPINGS' do
    let(:indexed_fields) { ::Search::Elastic::Types::WorkItem.mappings[:properties].keys }
    let(:sorted_fields) { described_class::SORT_MAPPINGS.values.flat_map(&:keys).uniq }

    it 'only sorts on fields present in the work item index mapping' do
      expect(indexed_fields).to include(*sorted_fields)
    end
  end
end
