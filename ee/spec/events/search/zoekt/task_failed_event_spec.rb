# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../ee/app/events/search/zoekt/task_failed_event'
require_relative '../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Search::Zoekt::TaskFailedEvent, feature_category: :global_search do
  it_behaves_like 'an event with schema',
    valid_data: { zoekt_repository_id: 1 },
    missing_required: %i[zoekt_repository_id],
    invalid_types: { zoekt_repository_id: 'not_an_integer', task_id: 'not_an_integer' }

  describe '#schema' do
    context 'with valid optional task_id' do
      it 'accepts an integer' do
        expect { described_class.new(data: { zoekt_repository_id: 1, task_id: 42 }) }.not_to raise_error
      end
    end
  end
end
