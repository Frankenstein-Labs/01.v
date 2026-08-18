# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/cd/artifact_published_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Cd::ArtifactPublishedEvent, feature_category: :continuous_delivery do
  it_behaves_like 'an event with schema',
    valid_data: {
      image: 'registry.example.com/my-image:latest', source_ref: 'registry.example.com/my-image',
      digest: 'sha256:abc', organization_id: 1, tag: 'latest'
    },
    missing_required: %i[image source_ref digest organization_id tag],
    invalid_types: { image: 123, digest: 456, organization_id: 'not_an_integer' }
end
