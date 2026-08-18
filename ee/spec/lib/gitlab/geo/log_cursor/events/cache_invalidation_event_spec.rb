# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::LogCursor::Events::CacheInvalidationEvent,
  :clean_gitlab_redis_shared_state,
  feature_category: :geo_replication do
  let(:logger) { Gitlab::Geo::LogCursor::Logger.new(described_class, Logger::INFO) }
  let(:event_log) { create(:geo_event_log, :cache_invalidation_event) }
  let!(:event_log_state) { create(:geo_event_log_state, event_id: event_log.id - 1) }
  let(:cache_invalidation_event) { event_log.cache_invalidation_event }
  let(:cache_key) { cache_invalidation_event.key }

  subject { described_class.new(cache_invalidation_event, Time.now, logger) }

  around do |example|
    Sidekiq::Testing.fake! { example.run }
  end

  describe '#process' do
    it 'expires the generic Redis (Rails.cache) cache of the given key' do
      expect(Rails.cache).to receive(:delete).with(cache_key).and_call_original

      subject.process
    end

    it 'expires the feature flag L2 (Feature.l2_cache_backend) cache for the given key' do
      expect(Feature.l2_cache_backend).to receive(:delete).with(cache_key).and_call_original

      subject.process
    end

    it 'removes stale values from all cache layers', :aggregate_failures do
      Rails.cache.write(cache_key, 'stale_value')
      Feature.l2_cache_backend.write(cache_key, 'stale_value')

      subject.process

      expect(Rails.cache.read(cache_key)).to be_nil
      expect(Feature.l2_cache_backend.read(cache_key)).to be_nil
    end

    it 'logs an info event' do
      data = {
        class: described_class.name,
        message: 'Cache invalidation',
        cache_key: cache_key,
        cache_expired: false,
        skippable: false,
        correlation_id: a_kind_of(String)
      }

      expect(::Gitlab::JsonLogger)
        .to receive(:info)
        .with(hash_including(:event_id, data))

      subject.process
    end
  end
end
