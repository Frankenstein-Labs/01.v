# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../ee/app/events/vulnerabilities/bulk_dismissed_event'
require_relative '../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Vulnerabilities::BulkDismissedEvent, feature_category: :vulnerability_management do
  it_behaves_like 'an event with schema',
    valid_data: {},
    missing_required: [],
    invalid_types: { vulnerabilities: 'not_an_array' }

  describe '#schema' do
    context 'with valid optional vulnerabilities' do
      it 'accepts an array of vulnerability objects with null comment' do
        data = {
          vulnerabilities: [
            {
              vulnerability_id: 1,
              project_id: 2,
              namespace_id: 3,
              dismissal_reason: 'used_in_tests',
              comment: nil,
              user_id: 4
            }
          ]
        }

        expect { described_class.new(data: data) }.not_to raise_error
      end
    end

    context 'with invalid vulnerabilities array items' do
      it 'raises an error when vulnerability_id is a string' do
        expect { described_class.new(data: { vulnerabilities: [{ vulnerability_id: 'not_an_integer' }] }) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end
    end
  end
end
