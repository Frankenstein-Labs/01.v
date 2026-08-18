# frozen_string_literal: true

require 'spec_helper'
require_relative 'shared_examples'

RSpec.describe Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs, feature_category: :code_suggestions do
  let_it_be(:params_queue_shards) { [4, 5, 6] }
  let_it_be(:params) do
    {
      'collection' => 'code',
      'queue_shards' => params_queue_shards
    }
  end

  let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }

  let(:task) { described_class.new(task_record) }

  let(:collection_class) { ::Ai::ActiveContext::Collections::Code }
  let(:queue_class) { collection_class.queue }

  it_behaves_like 'a batched active context task' do
    let(:required_params) { params }
  end

  describe '#execute!' do
    let_it_be(:task_record) do
      create(
        :ai_active_context_task,
        connection: connection,
        name: described_class.to_s,
        params: params
      )
    end

    context 'when collection record does not exist' do
      it 'raises an error' do
        expect { task.execute! }.to raise_error(
          described_class::TaskError, "Collection 'code' not found"
        )
      end
    end

    context 'when collection record exists' do
      before do
        allow(::ActiveContext::Config).to receive(:logger).and_return(logger)

        allow(::ActiveContext::Redis).to receive(:with_redis).and_yield(redis)

        allow(collection_class).to receive(:track!).and_call_original

        collection.update_options!(queue_shard_count: current_queue_shard_count)

        re_populate_queue(redis, collection_class, references_by_shard)
      end

      let_it_be_with_reload(:collection) do
        create(
          :ai_active_context_collection,
          :code_collection,
          connection: connection
        )
      end

      let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil) }

      let(:redis) { ::Gitlab::Redis::Cache.redis }

      let(:references_by_shard) do
        {
          4 => [
            { key: 'ref41', routing: 1, score: 1.0 },
            { key: 'ref42', routing: 2, score: 2.0 }
          ],
          5 => [
            { key: 'ref51', routing: 1, score: 1.0 }
          ]
        }
      end

      let(:all_references) do
        references_by_shard.values.flatten.map { |r| r[:key] }
      end

      context 'when all given `queue_shards` are orphaned' do
        # shards 0 - 3 are active
        let(:current_queue_shard_count) { 4 }

        it 're-enqueues refs from all given `queue_shards`' do
          expect(collection_class).to receive(:track!).with([
            { id: 'ref41', routing: 1 },
            { id: 'ref42', routing: 2 }
          ])
          expect(collection_class).to receive(:track!).with([{ id: 'ref51', routing: 1 }])

          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs',
            "message" => 'References reenqueued to active shards.',
            "orphaned_shard" => 4,
            "count" => 2,
            "min_score" => 1.0,
            "max_score" => 2.0
          }).ordered
          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs',
            "message" => 'References reenqueued to active shards.',
            "orphaned_shard" => 5,
            "count" => 1,
            "min_score" => 1.0,
            "max_score" => 1.0
          }).ordered
          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs',
            "message" => 'Orphaned shard is already empty.',
            "orphaned_shard" => 6
          }).ordered

          task.execute!

          expect(queue_class.queue_size(shards: params_queue_shards, include_orphaned: true)).to eq(0)
          expect(queue_class.queue_size(shards: [0, 1, 2, 3])).to eq(3)
          expect(all_refs_in_active_shards(collection_class)).to match_array(all_references)
        end
      end

      context 'when only some of the given queue_shards are orphaned' do
        # shards 0 - 4 are active
        let(:current_queue_shard_count) { 5 }

        it 're-enqueues refs from orphaned shards only' do
          expect(collection_class).to receive(:track!).with([{ id: 'ref51', routing: 1 }])

          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs',
            "message" => 'References reenqueued to active shards.',
            "orphaned_shard" => 5,
            "count" => 1,
            "min_score" => 1.0,
            "max_score" => 1.0
          }).ordered
          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs',
            "message" => 'Orphaned shard is already empty.',
            "orphaned_shard" => 6
          }).ordered

          task.execute!

          expect(queue_class.queue_size(shards: [5, 6], include_orphaned: true)).to eq(0)
          expect(queue_class.queue_size(shards: [0, 1, 2, 3, 4])).to eq(3)
          expect(all_refs_in_active_shards(collection_class)).to match_array(all_references)
        end
      end

      context 'when there are no orphaned queue shards' do
        # shards 0 - 9 are active
        let(:current_queue_shard_count) { 10 }

        it 'does not perform any reenqueue' do
          expect(collection_class).not_to receive(:track!)

          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs',
            "message" => 'No orphaned shards found.'
          })

          task.execute!

          expect(queue_class.queue_size(shards: params_queue_shards)).to eq(3)
          expect(queue_class.queue_size(shards: (0..9).to_a)).to eq(3)
          expect(all_refs_in_active_shards(collection_class)).to match_array(all_references)
        end
      end
    end
  end

  describe '#completed?' do
    subject(:completed) { task.completed? }

    context 'when collection cache has not been refreshed', :freeze_time do
      let(:task_record) do
        create(
          :ai_active_context_task,
          connection: connection,
          name: described_class.to_s,
          params: params,
          created_at: task_created_at
        )
      end

      context 'with time elapsed since update less than collection cache ttl' do
        let(:task_created_at) { Time.current - (::ActiveContext::CollectionCache::TTL - 1.second) }

        it { is_expected.to be(false) }
      end

      context 'with time elapsed since update equal to collection cache ttl' do
        let(:task_created_at) { Time.current - ::ActiveContext::CollectionCache::TTL }

        it { is_expected.to be(false) }
      end
    end

    context 'when collection cache has been refreshed' do
      let_it_be(:task_record) do
        task_created_at = Time.current - (::ActiveContext::CollectionCache::TTL + 1.second)
        create(
          :ai_active_context_task,
          connection: connection,
          name: described_class.to_s,
          params: params,
          created_at: task_created_at
        )
      end

      context 'when collection record does not exist' do
        it 'raises an error' do
          expect { completed }.to raise_error(
            described_class::TaskError, "Collection 'code' not found"
          )
        end
      end

      context 'when collection record exists' do
        shared_examples 'checks the queue size for the orphaned shards' do
          context 'when the queue size for the given shards is greater than 0' do
            it 'returns false' do
              allow(queue_class).to receive(:queue_size)
                .with(shards: expected_orphaned_shards, include_orphaned: true).and_return(1)

              expect(completed).to be(false)
            end
          end

          context 'when the queue size for the given shards is 0' do
            it 'returns true' do
              allow(queue_class).to receive(:queue_size)
                .with(shards: expected_orphaned_shards, include_orphaned: true).and_return(0)

              expect(completed).to be(true)
            end
          end
        end

        let_it_be_with_reload(:collection) do
          create(
            :ai_active_context_collection,
            :code_collection,
            connection: connection
          )
        end

        context 'when there are no orphaned queue shards' do
          before do
            collection.update_options!(queue_shard_count: 10)
          end

          it { is_expected.to be(true) }
        end

        context 'when the given `queue_shards` are orphaned' do
          before do
            collection.update_options!(queue_shard_count: 4)
          end

          it_behaves_like 'checks the queue size for the orphaned shards' do
            let(:expected_orphaned_shards) { [4, 5, 6] }
          end
        end

        context 'when only some of the given `queue_shards` are orphaned' do
          before do
            collection.update_options!(queue_shard_count: 5)
          end

          it_behaves_like 'checks the queue size for the orphaned shards' do
            let(:expected_orphaned_shards) { [5, 6] }
          end
        end
      end
    end
  end

  def all_refs_in_active_shards(collection_class)
    collection_class.queue.queued_items.values.flatten(1).map do |scored_ref|
      _collection_id,
      _routing,
      ref_key = collection_class.reference_klass.deserialize_string(scored_ref.first)

      ref_key
    end
  end

  def re_populate_queue(redis, collection_class, references_by_shard)
    collection_class.queue.clear_tracking!

    references_by_shard.each do |shard_number, refs_with_score|
      elements_to_add = refs_with_score.map do |r|
        [
          r[:score],
          full_ref_key(collection_class, r[:key], r[:routing])
        ]
      end

      redis.zadd(
        collection_class.queue.redis_set_key(shard_number),
        elements_to_add
      )
    end
  end

  def full_ref_key(collection_class, ref, routing)
    collection_class.reference_klass.serialize(
      collection_id: collection_class.collection_record.id,
      routing: routing,
      data: { id: ref }
    )
  end
end
