# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::DeadQueue,
  :clean_gitlab_redis_shared_state,
  feature_category: :global_search do
  let(:ref_class) { ::Search::Elastic::DocumentReference }
  let(:fake_refs) { (1..10).map { |i| ref_class.new(Issue, i, "issue_#{i}", 'project_1') } }
  let(:issue) { fake_refs.first }
  let(:issue_spec) { issue.serialize }

  describe '.redis_set_key' do
    it 'returns correct redis key' do
      expect(described_class.redis_set_key(0)).to eq('elastic:dead_queue:0:zset')
    end
  end

  describe '.redis_score_key' do
    it 'returns correct redis score key' do
      expect(described_class.redis_score_key(0)).to eq('elastic:dead_queue:0:score')
    end
  end

  describe '.active_number_of_shards' do
    it 'returns 1 shard' do
      expect(described_class.active_number_of_shards).to eq(1)
    end
  end

  describe '.track!' do
    it 'enqueues a record' do
      described_class.track!(issue)

      shard = described_class.shard_number(issue_spec)
      spec, score = described_class.queued_items[shard].first

      expect(spec).to eq(issue_spec)
      expect(score).to eq(1.0)
    end

    it 'enqueues a set of unique records' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)
    end

    it 'logs a warning when items are added' do
      logger = double
      allow(described_class).to receive(:logger).and_return(logger)
      allow(logger).to receive(:debug)

      described_class.track!(issue)

      expect(logger).to have_received(:debug).with(
        hash_including(
          'class' => 'Search::Elastic::DeadQueue',
          'message' => 'track_items'
        )
      )
    end
  end

  describe '.queue_size' do
    it 'returns the total queue size across all shards' do
      expect(described_class.queue_size).to eq(0)

      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)
    end
  end

  describe '.clear_tracking!' do
    it 'removes all items from the queue' do
      described_class.track!(*fake_refs)

      expect(described_class.queue_size).to eq(fake_refs.size)

      described_class.clear_tracking!

      expect(described_class.queue_size).to eq(0)
    end
  end
end
