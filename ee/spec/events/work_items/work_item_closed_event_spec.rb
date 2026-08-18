# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/work_items/work_item_closed_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe WorkItems::WorkItemClosedEvent, feature_category: :team_planning do
  it_behaves_like 'an event with schema',
    valid_data: { id: 1, namespace_id: 2 },
    missing_required: %i[id namespace_id],
    invalid_types: { id: 'not_an_integer', namespace_id: 'not_an_integer' }
end
