# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../ee/app/events/search/zoekt/initial_indexing_event'
require_relative '../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Search::Zoekt::InitialIndexingEvent, feature_category: :global_search do
  it_behaves_like 'an event with schema',
    valid_data: { index_id: 1 },
    missing_required: %i[index_id],
    invalid_types: { index_id: 'not_an_integer' }
end
