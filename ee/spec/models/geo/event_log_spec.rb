# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::EventLog, type: :model, feature_category: :geo_replication do
  describe 'relationships' do
    it { is_expected.to belong_to(:cache_invalidation_event).class_name('Geo::CacheInvalidationEvent').with_foreign_key('cache_invalidation_event_id') }
  end

  describe '.next_unprocessed_event' do
    it 'returns next unprocessed event' do
      processed_event = create(:geo_event_log)
      unprocessed_event = create(:geo_event_log)
      create(:geo_event_log_state, event_id: processed_event.id)

      expect(described_class.next_unprocessed_event).to eq unprocessed_event
    end

    it 'returns the oldest event when there are no processed events yet' do
      oldest_event = create(:geo_event_log)
      create(:geo_event_log)

      expect(described_class.next_unprocessed_event).to eq oldest_event
    end

    it 'returns nil when there are no events yet' do
      expect(described_class.next_unprocessed_event).to be_nil
    end
  end

  describe '.event_classes' do
    it 'returns all event class reflections' do
      reflections = described_class.reflections.map { |_k, v| v.class_name.constantize }

      expect(described_class.event_classes).to contain_exactly(*reflections)
    end
  end

  describe '#event' do
    it 'returns nil when having no event associated' do
      expect(subject.event).to be_nil
    end

    it 'returns cache_invalidation_event when set' do
      cache_invalidation_event = build(:geo_cache_invalidation_event)
      subject.cache_invalidation_event = cache_invalidation_event

      expect(subject.event).to eq cache_invalidation_event
    end
  end

  describe '#project_id' do
    it 'returns nil when having no event associated' do
      expect(subject.project_id).to be_nil
    end

    it 'returns nil when an event does not respond to project_id' do
      cache_invalidation_event = build(:geo_cache_invalidation_event)
      subject.cache_invalidation_event = cache_invalidation_event

      expect(subject.project_id).to be_nil
    end
  end
end
