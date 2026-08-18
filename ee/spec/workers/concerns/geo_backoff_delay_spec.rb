# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GeoBackoffDelay, feature_category: :geo_replication do
  let(:worker_class) do
    Class.new do
      def self.name
        'Geo::TestWorker'
      end

      include ApplicationWorker
      include GeoBackoffDelay
    end
  end

  let(:worker) { worker_class.new }

  describe '#skip_cache_key' do
    it 'returns cache key based on worker class name' do
      expect(worker.skip_cache_key).to eq('geo/test_worker:skip')
    end
  end

  describe 'backoff behavior', :use_clean_rails_memory_store_caching do
    it 'skips the worker after setting backoff time' do
      expect(worker.should_be_skipped?).to be_falsey

      worker.set_backoff_time!

      expect(worker.should_be_skipped?).to be true
    end
  end
end
