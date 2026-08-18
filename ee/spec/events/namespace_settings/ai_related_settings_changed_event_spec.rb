# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/namespace_settings/ai_related_settings_changed_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe NamespaceSettings::AiRelatedSettingsChangedEvent, feature_category: :duo_chat do
  it_behaves_like 'an event with schema',
    valid_data: { group_id: 1 },
    missing_required: %i[group_id],
    invalid_types: { group_id: 'not_an_integer' }
end
