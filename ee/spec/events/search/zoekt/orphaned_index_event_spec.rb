# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../ee/app/events/search/zoekt/orphaned_index_event'
require_relative '../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Search::Zoekt::OrphanedIndexEvent, feature_category: :global_search do
  it_behaves_like 'an event with schema',
    valid_data: {},
    missing_required: [],
    invalid_types: { index_ids: 'not_an_array' }

  describe '#schema' do
    context 'with valid optional index_ids' do
      it 'accepts an array of integers' do
        expect { described_class.new(data: { index_ids: [1, 2, 3] }) }.not_to raise_error
      end
    end

    context 'with invalid index_ids array items' do
      it 'raises an error when index_ids contains non-integers' do
        expect { described_class.new(data: { index_ids: ['not_an_integer'] }) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end
    end
  end
end
