# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::UpdateQueueShardCountService, feature_category: :global_search do
  describe '#execute' do
    before do
      allow(::ActiveContext::Config).to receive(:logger).and_return(logger)
    end

    let(:logger) { instance_double(::Gitlab::ActiveContext::Logger, info: nil) }

    let(:collection_class) { ::Ai::ActiveContext::Collections::Code }
    let(:queue_shard_count) { 2 }

    let_it_be(:connection) { create(:ai_active_context_connection, :elasticsearch) }
    let_it_be_with_reload(:collection_record) do
      create(:ai_active_context_collection, :code_collection, connection: connection)
    end

    subject(:execute) do
      described_class.new(
        collection_class: collection_class,
        queue_shard_count: queue_shard_count
      ).execute
    end

    context 'when ActiveContext indexing is disabled' do
      it 'returns an error response' do
        allow(::ActiveContext).to receive(:indexing?).and_return(false)

        result = execute
        expect(result).to be_error
        expect(result.message).to eq('indexing is disabled')
      end
    end

    describe 'invalid queue_shard_count values' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(true)
      end

      where(:queue_shard_count) do
        [0, -1, nil, "str"]
      end

      with_them do
        it 'returns an error response' do
          result = execute
          expect(result).to be_error
          expect(result.message).to eq('queue_shard_count must be a positive integer')
        end
      end
    end

    context 'when collection record does not exist' do
      it 'returns an error response' do
        allow(::ActiveContext).to receive(:indexing?).and_return(true)
        allow(collection_class).to receive(:collection_record).and_return(nil)

        result = execute
        expect(result).to be_error
        expect(result.message).to eq('collection_record not found')
      end
    end

    context 'when there are pending or in-progress ReenqueueOrphanedRefs tasks' do
      it 'returns an error response' do
        allow(::ActiveContext).to receive(:indexing?).and_return(true)
        allow(collection_class).to receive(:collection_record).and_return(collection_record)

        create(:ai_active_context_task, connection: connection,
          name: ::Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs.name)
        create(:ai_active_context_task, :in_progress, connection: connection,
          name: ::Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs.name)

        result = execute
        expect(result).to be_error
        expect(result.message).to eq('shard rebalancing in progress, please try again later')
      end
    end

    context 'when all pre-requisites are satisfied' do
      before do
        allow(::ActiveContext).to receive(:indexing?).and_return(true)

        allow(::Ai::ActiveContext::TaskService).to receive(:new).and_call_original

        # create ReenqueueOrphanedRefs that are not processable
        inactive_connection = create(:ai_active_context_connection, :inactive)
        create(:ai_active_context_task, :in_progress, connection: inactive_connection,
          name: ::Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs.name)
        create(:ai_active_context_task, :failed, connection: connection,
          name: ::Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs.name)
        create(:ai_active_context_task, :completed, connection: connection,
          name: ::Ai::ActiveContext::Tasks::ReenqueueOrphanedRefs.name)

        allow(collection_record).to receive(:update_options!).and_call_original
        allow(collection_class).to receive(:collection_record).and_return(collection_record)
      end

      let(:queue_shard_count) { 2 }

      context 'when new queue_shard_count is equal to the previous one' do
        before do
          collection_record.update_options!(queue_shard_count: 2)
        end

        it 'does not make any updates' do
          expect(collection_record).not_to receive(:update_options!)
          result = nil

          expect do
            result = execute
          end.not_to change { ::Ai::ActiveContext::Task.count }

          expect(result).to be_success
          expect(result.payload).to eq({
            updated: false,
            message: 'The queue_shard_count value is the same as the current one.'
          })
        end
      end

      context 'when new queue_shard_count is greater than the previous one' do
        before do
          collection_record.update_options!(queue_shard_count: 1)
        end

        it 'updates the collection.queue_shard_count but does not create tasks' do
          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::UpdateQueueShardCountService',
            "collection" => "code",
            "message" => 'queue_shard_count updated',
            "old_value" => 1,
            "new_value" => 2,
            "reenqueued_shards" => []
          })

          result = nil

          expect do
            result = execute
          end.not_to change { ::Ai::ActiveContext::Task.count }

          expect(result).to be_success
          expect(result.payload).to eq({ updated: true, reenqueued_shards: [] })
          expect(collection_record.queue_shard_count).to eq(2)
        end
      end

      context 'when new queue_shard_count is less than the previous one' do
        before do
          collection_record.update_options!(queue_shard_count: 10)
        end

        it 'updates the collection.queue_shard_count and creates the expected tasks' do
          expected_reenqueued_shards = [2, 3, 4, 5, 6, 7, 8, 9]

          expect(logger).to receive(:info).with({
            "class_name" => 'Ai::ActiveContext::UpdateQueueShardCountService',
            "message" => 'queue_shard_count updated',
            "collection" => "code",
            "old_value" => 10,
            "new_value" => 2,
            "reenqueued_shards" => expected_reenqueued_shards
          })

          result = nil

          expect do
            result = execute
          end.to change { ::Ai::ActiveContext::Task.count }.by(2)

          expect(result).to be_success
          expect(result.payload).to eq({
            updated: true,
            reenqueued_shards: expected_reenqueued_shards
          })

          created_tasks = ::Ai::ActiveContext::Task.order(id: :desc).limit(2)
          expect(created_tasks[0].params).to eq({ 'collection' => 'code', 'queue_shards' => [7, 8, 9] })
          expect(created_tasks[1].params).to eq({ 'collection' => 'code', 'queue_shards' => [2, 3, 4, 5, 6] })

          expect(collection_record.queue_shard_count).to eq(2)
        end

        context 'when there is an error in task creation' do
          before do
            allow(::Ai::ActiveContext::TaskService).to receive(:new).and_return(task_service)
          end

          let(:task_service) { instance_double(Ai::ActiveContext::TaskService, :create_task) }

          it 'does not update the queue_shard_count' do
            allow(task_service).to receive(:create_task).and_raise(StandardError, 'some error')

            expect { execute }.to raise_error(StandardError, 'some error')

            expect(collection_record.reload.queue_shard_count).to eq(10)
          end
        end
      end
    end
  end
end
