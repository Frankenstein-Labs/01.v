# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::LatestGraphTimestampCacheKey, :freeze_time, feature_category: :dependency_management do
  let_it_be(:project) { build_stubbed(:project) }
  let(:expected_cache_key) { "#{described_class}-latest-sbom-graph-timestamp-#{project.id}" }
  let(:timestamp) { DateTime.now }

  subject(:service) { described_class.new(project: project) }

  describe '#store' do
    it 'stores the key in cache' do
      expect(Rails.cache).to receive(:write).with(expected_cache_key, timestamp,
        expires_in: described_class::CACHE_EXPIRATION_TIME).and_return("OK")
      service.store(timestamp)
    end
  end

  describe '#retrieve' do
    it 'fetches the timestamp' do
      expect(Rails.cache).to receive(:read).with(expected_cache_key)
      service.retrieve
    end
  end

  describe '#cache_key' do
    it 'builds the cache key using class name and project ID' do
      expect(service.cache_key).to eq(expected_cache_key)
    end
  end
end
