# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../ee/app/events/search/zoekt/node_with_negative_unclaimed_storage_event'
require_relative '../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent, feature_category: :global_search do
  it_behaves_like 'an event with schema',
    valid_data: { node_ids: [1, 2, 3] },
    missing_required: %i[node_ids],
    invalid_types: { node_ids: 'not_an_array' }

  describe '#schema' do
    context 'with invalid node_ids array items' do
      it 'raises an error when node_ids contains non-integers' do
        expect { described_class.new(data: { node_ids: ['not_an_integer'] }) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end
    end
  end
end
