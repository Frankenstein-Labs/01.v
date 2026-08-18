# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/security/policy_dismissal_preserved_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Security::PolicyDismissalPreservedEvent, feature_category: :security_policy_management do
  it_behaves_like 'an event with schema',
    valid_data: { security_policy_dismissal_id: 1 },
    missing_required: %i[security_policy_dismissal_id],
    invalid_types: { security_policy_dismissal_id: 'not_an_integer' }
end
