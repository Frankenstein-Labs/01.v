# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/security/policy_resync_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Security::PolicyResyncEvent, feature_category: :security_policy_management do
  it_behaves_like 'an event with schema',
    valid_data: { security_policy_id: 1 },
    missing_required: %i[security_policy_id],
    invalid_types: { security_policy_id: 'not_an_integer' }
end
