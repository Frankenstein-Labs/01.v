# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::ElasticsearchEnabledCache, :clean_gitlab_redis_cache, feature_category: :global_search do
  describe '.fetch' do
    it 'remembers the result of the first invocation' do
      expect(described_class.fetch(:project, 1) { true }).to be(true)
      expect(described_class.fetch(:project, 2) { false }).to be(false)

      expect { |b| described_class.fetch(:project, 1, &b) }.not_to yield_control
      expect { |b| described_class.fetch(:project, 2, &b) }.not_to yield_control

      expect(described_class.fetch(:project, 1) { false }).to be(true)
      expect(described_class.fetch(:project, 2) { true }).to be(false)
    end

    it 'sets an expiry on the key the first time it creates the hash' do
      stub_const('::Search::Elastic::ElasticsearchEnabledCache::EXPIRES_IN', 0)

      expect(described_class.fetch(:project, 1) { true }).to be(true)
      expect(described_class.fetch(:project, 2) { false }).to be(false)

      expect(described_class.fetch(:project, 1) { false }).to be(false)
      expect(described_class.fetch(:project, 2) { true }).to be(true)
    end

    it 'does not set an expiry on the key after the hash is already created' do
      expect(described_class.fetch(:project, 1) { true }).to be(true)

      stub_const('::Search::Elastic::ElasticsearchEnabledCache::EXPIRES_IN', 0)

      expect(described_class.fetch(:project, 2) { false }).to be(false)

      expect(described_class.fetch(:project, 1) { false }).to be(true)
      expect(described_class.fetch(:project, 2) { true }).to be(false)
    end
  end

  describe '.delete' do
    it 'clears the cached value' do
      expect(described_class.fetch(:project, 1) { true }).to be(true)
      expect(described_class.fetch(:project, 2) { false }).to be(false)

      described_class.delete(:project)

      expect(described_class.fetch(:project, 1) { false }).to be(false)
      expect(described_class.fetch(:project, 2) { true }).to be(true)
    end

    it 'does not clear the cache for another type' do
      expect(described_class.fetch(:project, 1) { true }).to be(true)
      expect(described_class.fetch(:namespace, 1) { false }).to be(false)

      described_class.delete(:project)

      expect(described_class.fetch(:project, 1) { false }).to be(false)
      expect(described_class.fetch(:namespace, 1) { true }).to be(false)
    end
  end

  describe '.delete_record' do
    it 'clears the cached value' do
      expect(described_class.fetch(:project, 1) { true }).to be(true)

      described_class.delete_record(:project, 1)

      expect(described_class.fetch(:project, 1) { false }).to be(false)
    end

    it 'does not clear the cache for another record of the same type' do
      expect(described_class.fetch(:project, 1) { true }).to be(true)
      expect(described_class.fetch(:project, 2) { false }).to be(false)

      described_class.delete_record(:project, 1)

      expect(described_class.fetch(:project, 1) { false }).to be(false)
      expect(described_class.fetch(:project, 2) { true }).to be(false)
    end

    it 'does not clear the cache for another record of a different type' do
      expect(described_class.fetch(:project, 1) { true }).to be(true)
      expect(described_class.fetch(:namespace, 1) { false }).to be(false)

      described_class.delete_record(:project, 1)

      expect(described_class.fetch(:project, 1) { false }).to be(false)
      expect(described_class.fetch(:namespace, 1) { true }).to be(false)
    end
  end
end
