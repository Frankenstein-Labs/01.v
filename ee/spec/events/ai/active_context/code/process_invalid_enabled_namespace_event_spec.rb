# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../../ee/app/events/ai/active_context/code/process_invalid_enabled_namespace_event'
require_relative '../../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Ai::ActiveContext::Code::ProcessInvalidEnabledNamespaceEvent, feature_category: :duo_chat do
  it_behaves_like 'an event with schema',
    valid_data: {},
    missing_required: [],
    invalid_types: { last_processed_id: 'invalid' }

  describe '#schema' do
    context 'with valid optional last_processed_id' do
      it 'accepts an integer' do
        expect { described_class.new(data: { last_processed_id: 42 }) }.not_to raise_error
      end

      it 'accepts null' do
        expect { described_class.new(data: { last_processed_id: nil }) }.not_to raise_error
      end
    end

    context 'with extra properties' do
      it 'raises an error' do
        expect { described_class.new(data: { unexpected: 'data' }) }
          .to raise_error(Gitlab::EventStore::InvalidEvent, /does not match/)
      end
    end
  end
end
