# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/merge_requests/closed_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe MergeRequests::ClosedEvent, feature_category: :code_review_workflow do
  it_behaves_like 'an event with schema',
    valid_data: { merge_request_id: 1 },
    missing_required: %i[merge_request_id],
    invalid_types: { merge_request_id: 'not_an_integer' }

  describe '#schema' do
    it 'allows dependency management auto-remediation source' do
      source = described_class::SOURCE_TYPES[:dependency_management_auto_remediation]

      expect { described_class.new(data: { merge_request_id: 1, source: source }) }.not_to raise_error
    end

    it 'raises an error for unsupported source' do
      expect { described_class.new(data: { merge_request_id: 1, source: 'unsupported' }) }
        .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
    end
  end
end
