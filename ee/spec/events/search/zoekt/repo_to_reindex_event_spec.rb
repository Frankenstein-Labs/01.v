# frozen_string_literal: true

require 'fast_spec_helper'
require_relative '../../../../../ee/app/events/search/zoekt/repo_to_reindex_event'
require_relative '../../../../../spec/support/shared_examples/events/event_with_schema_shared_examples'

RSpec.describe Search::Zoekt::RepoToReindexEvent, feature_category: :global_search do
  it_behaves_like 'an event with schema',
    valid_data: {},
    missing_required: [],
    invalid_types: { zoekt_node_id: 'not_an_integer' }

  describe '#schema' do
    context 'with valid optional zoekt_node_id' do
      it 'accepts an integer' do
        expect { described_class.new(data: { zoekt_node_id: 1 }) }.not_to raise_error
      end

      it 'accepts null' do
        expect { described_class.new(data: { zoekt_node_id: nil }) }.not_to raise_error
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
