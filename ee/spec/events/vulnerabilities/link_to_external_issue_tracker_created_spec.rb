# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/vulnerabilities/link_to_external_issue_tracker_created'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Vulnerabilities::LinkToExternalIssueTrackerCreated, feature_category: :vulnerability_management do
  it_behaves_like 'an event with schema',
    valid_data: { vulnerability_id: 1 },
    missing_required: %i[vulnerability_id],
    invalid_types: { vulnerability_id: 'not_an_integer' }
end
