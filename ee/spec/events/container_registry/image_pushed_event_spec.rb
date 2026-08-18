# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/container_registry/image_pushed_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe ContainerRegistry::ImagePushedEvent, feature_category: :container_registry do
  it_behaves_like 'an event with schema',
    valid_data: { project_id: 1, image: 'registry.example.com/my-image:latest' },
    missing_required: %i[project_id image],
    invalid_types: { project_id: 'not_an_integer', image: 123 }
end
