# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/members/membership_modified_by_admin_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Members::MembershipModifiedByAdminEvent, feature_category: :seat_cost_management do
  it_behaves_like 'an event with schema',
    valid_data: { member_user_id: 1 },
    missing_required: %i[member_user_id],
    invalid_types: { member_user_id: 'not_an_integer' }
end
