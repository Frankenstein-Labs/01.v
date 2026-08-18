# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples'

RSpec.describe Ai::ActiveContext::Tasks::ReplayDeadQueue, feature_category: :global_search do
  let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }
  let_it_be(:params) { { 'queue_name' => 'retry_queue', 'max_score' => 100.0 } }

  let(:task_record) do
    create(:ai_active_context_task, connection: connection, name: described_class.to_s, params: params)
  end

  let(:task) { described_class.new(task_record) }

  it_behaves_like 'a batched active context task' do
    let(:required_params) { params }
  end

  describe '#execute!' do
    let(:redis) { ::Gitlab::Redis::Cache.redis }
    let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil) }

    before do
      allow(::ActiveContext::Redis).to receive(:with_redis).and_yield(redis)
      allow(::ActiveContext::Config).to receive_messages(logger: logger, queue_classes: [])
      redis.del(::ActiveContext::DeadQueue.redis_set_key(0))
    end

    context 'when the dead queue is empty' do
      it 'does not push anything to the target queue' do
        expect(::ActiveContext::RetryQueue).not_to receive(:push)

        task.execute!
      end
    end

    context 'when the dead queue has items within max_score' do
      let(:items) { [['ref:1', 10.0], ['ref:2', 20.0], ['ref:3', 30.0]] }

      before do
        items.each do |spec, score|
          redis.zadd(::ActiveContext::DeadQueue.redis_set_key(0), score, spec)
        end
      end

      it 'pushes specs to the target queue' do
        expect(::ActiveContext::RetryQueue).to receive(:push).with(%w[ref:1 ref:2 ref:3])

        task.execute!
      end

      it 'removes the items from the dead queue' do
        task.execute!

        expect(redis.zcard(::ActiveContext::DeadQueue.redis_set_key(0))).to eq(0)
      end

      it 'logs the replayed batch' do
        expect(logger).to receive(:info).with(hash_including(
          'message' => 'Replayed dead queue batch',
          'target_queue' => 'retry_queue',
          'shard' => 0,
          'replayed' => 3
        ))

        task.execute!
      end
    end

    context 'when there are items beyond max_score' do
      before do
        redis.zadd(::ActiveContext::DeadQueue.redis_set_key(0), 50.0, 'ref:within')
        redis.zadd(::ActiveContext::DeadQueue.redis_set_key(0), 200.0, 'ref:beyond')
      end

      it 'only pushes items within max_score' do
        expect(::ActiveContext::RetryQueue).to receive(:push).with(['ref:within'])

        task.execute!
      end

      it 'leaves items beyond max_score in the dead queue' do
        task.execute!

        remaining = redis.zrangebyscore(::ActiveContext::DeadQueue.redis_set_key(0), '-inf', '+inf')
        expect(remaining).to eq(['ref:beyond'])
      end
    end
  end

  describe '#completed?' do
    let(:redis) { ::Gitlab::Redis::Cache.redis }

    before do
      allow(::ActiveContext::Redis).to receive(:with_redis).and_yield(redis)
      redis.del(::ActiveContext::DeadQueue.redis_set_key(0))
    end

    context 'when there are no items within max_score' do
      it { expect(task.completed?).to be(true) }
    end

    context 'when there are items within max_score' do
      before do
        redis.zadd(::ActiveContext::DeadQueue.redis_set_key(0), 50.0, 'ref:1')
      end

      it { expect(task.completed?).to be(false) }
    end

    context 'when items exist only beyond max_score' do
      before do
        redis.zadd(::ActiveContext::DeadQueue.redis_set_key(0), 200.0, 'ref:beyond')
      end

      it { expect(task.completed?).to be(true) }
    end
  end
end
