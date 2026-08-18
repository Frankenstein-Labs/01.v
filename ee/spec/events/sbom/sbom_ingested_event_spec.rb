# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/sbom/sbom_ingested_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Sbom::SbomIngestedEvent, feature_category: :software_composition_analysis do
  it_behaves_like 'an event with schema',
    valid_data: { pipeline_id: 1 },
    missing_required: %i[pipeline_id],
    invalid_types: { pipeline_id: 'not_an_integer' }
end
