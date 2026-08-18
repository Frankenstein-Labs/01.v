# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/security/reports_ingested_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Security::ReportsIngestedEvent, feature_category: :security_policy_management do
  it_behaves_like 'an event with schema',
    valid_data: { pipeline_id: 1 },
    missing_required: %i[pipeline_id],
    invalid_types: { pipeline_id: 'not_an_integer' }
end
