# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/ci/job_security_scan_completed_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Ci::JobSecurityScanCompletedEvent, feature_category: :continuous_integration do
  it_behaves_like 'an event with schema',
    valid_data: { job_id: 1 },
    missing_required: %i[job_id],
    invalid_types: { job_id: 'not_an_integer' }
end
