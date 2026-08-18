# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../ee/app/events/ai/duo_workflows/workflow_started_event'
require_relative '../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Ai::DuoWorkflows::WorkflowStartedEvent, feature_category: :duo_agent_platform do
  it_behaves_like 'an event with schema',
    valid_data: { workflow_id: 1 },
    missing_required: %i[workflow_id],
    invalid_types: { workflow_id: 'not_an_integer' }
end
