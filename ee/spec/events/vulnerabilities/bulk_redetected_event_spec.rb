# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/vulnerabilities/bulk_redetected_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Vulnerabilities::BulkRedetectedEvent, feature_category: :vulnerability_management do
  it_behaves_like 'an event with schema',
    valid_data: {},
    missing_required: [],
    invalid_types: { vulnerabilities: 'not_an_array' }

  describe '#schema' do
    context 'with valid optional vulnerabilities' do
      it 'accepts an array of vulnerability objects with date-time timestamp' do
        data = {
          vulnerabilities: [
            {
              vulnerability_id: 1,
              pipeline_id: 2,
              timestamp: '2024-01-10T12:00:00Z'
            }
          ]
        }

        expect { described_class.new(data: data) }.not_to raise_error
      end
    end

    context 'with invalid vulnerabilities array items' do
      it 'raises an error when timestamp has an invalid format' do
        expect { described_class.new(data: { vulnerabilities: [{ timestamp: 'not-a-date' }] }) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end
    end
  end
end
