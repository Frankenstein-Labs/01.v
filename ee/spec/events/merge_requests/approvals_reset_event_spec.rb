# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/merge_requests/approvals_reset_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe MergeRequests::ApprovalsResetEvent, feature_category: :code_review_workflow do
  it_behaves_like 'an event with schema',
    valid_data: {
      current_user_id: 1,
      merge_request_id: 2,
      cause: 'new_push',
      approver_ids: [3, 4]
    },
    missing_required: %i[current_user_id merge_request_id cause approver_ids],
    invalid_types: {
      current_user_id: 'not_an_integer',
      cause: 123,
      approver_ids: 'not_an_array'
    }
end
