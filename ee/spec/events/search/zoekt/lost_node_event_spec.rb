# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../ee/app/events/search/zoekt/lost_node_event'
require_relative '../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Search::Zoekt::LostNodeEvent, feature_category: :global_search do
  it_behaves_like 'an event with schema',
    valid_data: { zoekt_node_id: 1 },
    missing_required: %i[zoekt_node_id],
    invalid_types: { zoekt_node_id: 'not_an_integer' }
end
