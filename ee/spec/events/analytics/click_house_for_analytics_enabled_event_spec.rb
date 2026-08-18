# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/analytics/click_house_for_analytics_enabled_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Analytics::ClickHouseForAnalyticsEnabledEvent, feature_category: :product_analytics do
  it_behaves_like 'an event with schema',
    valid_data: { enabled_at: '2024-01-10T12:00:00Z' },
    missing_required: %i[enabled_at],
    invalid_types: { enabled_at: 'not-a-date' }
end
