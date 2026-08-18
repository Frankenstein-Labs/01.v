# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::ActiveContext::BulkProcessWorker, :with_active_context_adapter_reset, feature_category: :global_search do
  let(:worker) { described_class.new }
  let(:queue_class) { Ai::ActiveContext::TestQueue }
  let(:queue_class_name) { Ai::ActiveContext::TestQueue.to_s }
  let(:shard) { 1 }

  before do
    allow(queue_class).to receive(:number_of_shards).and_return(shard)
  end

  it_behaves_like 'an idempotent worker' do
    let(:job_args) { [queue_class_name, 1] }
  end

  it { is_expected.to be_a(ApplicationWorker) }
  it { is_expected.to be_a(CronjobQueue) }
  it { is_expected.to be_a(Search::Worker) }

  it { expect(described_class.get_concurrency_limit).to eq(200) }

  it_behaves_like 'active_context pause-controlled worker' do
    let(:worker_params) { [] }
  end

  describe '#perform' do
    before do
      allow(::ActiveContext).to receive_message_chain(:adapter, :full_collection_name)
        .and_return(ActiveContextHelpers.code_collection_name)
    end

    context 'when indexing is disabled' do
      before do
        allow(ActiveContext).to receive(:indexing?).and_return(false)
      end

      it 'returns false' do
        expect(worker.perform).to be false
      end
    end

    context 'when no arguments are provided' do
      it 'enqueues all shards' do
        expect(described_class).to receive(:bulk_perform_async_with_contexts)
        worker.perform
      end
    end

    context 'when arguments are provided' do
      before do
        allow(worker).to receive(:process_shard).and_call_original

        allow(ActiveContext::BulkProcessQueue).to receive(:process!).and_return([10, 0])
      end

      it 'processes the queue shard and logs metadata' do
        expect(ActiveContext::BulkProcessQueue).to receive(:process!).with(queue_class, shard)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:records_count, 10)
        expect(worker).to receive(:log_extra_metadata_on_done).with(:shard_number, shard)

        worker.perform(queue_class_name, shard)
      end

      it 'handles FailedToObtainLockError' do
        allow(worker).to receive(:process_shard).and_raise(Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError)
        expect { worker.perform(queue_class_name, shard) }.not_to raise_error
      end

      context 'when re_enqueue_indexing_workers config is true' do
        before do
          allow(ActiveContext::Config).to receive(:re_enqueue_indexing_workers?).and_return(true)
        end

        it 're-enqueues the shard' do
          expect(ActiveContext::BulkProcessQueue).to receive(:process!).with(queue_class, shard)
          expect(described_class).to receive(:perform_in).with(
            described_class::RESCHEDULE_INTERVAL, queue_class_name, shard
          )

          worker.perform(queue_class_name, shard)
        end

        it 'does not re-enqueue the shard if there are no remaining refs for processing' do
          allow(ActiveContext::BulkProcessQueue).to receive(:process!).and_return([0, 0])

          expect(ActiveContext::BulkProcessQueue).to receive(:process!).with(queue_class, shard)
          expect(described_class).not_to receive(:perform_in)

          worker.perform(queue_class_name, shard)
        end

        it 'does not re-enqueue the shard if there are failed refs' do
          allow(ActiveContext::BulkProcessQueue).to receive(:process!).and_return([10, 10])

          expect(ActiveContext::BulkProcessQueue).to receive(:process!).with(queue_class, shard)
          expect(described_class).not_to receive(:perform_in)

          worker.perform(queue_class_name, shard)
        end

        it 'does not re-enqueue the shard if the queue limits throughput' do
          allow(queue_class).to receive(:limit_throughput?).and_return(true)

          expect(ActiveContext::BulkProcessQueue).to receive(:process!).with(queue_class, shard)
          expect(described_class).not_to receive(:perform_in)

          worker.perform(queue_class_name, shard)
        end
      end

      context 'when re_enqueue_indexing_workers config is false' do
        before do
          allow(ActiveContext::Config).to receive(:re_enqueue_indexing_workers?).and_return(false)
        end

        it 'does not re-enqueue the shard' do
          expect(described_class).not_to receive(:perform_in)
          worker.perform(queue_class_name, shard)
        end
      end
    end
  end
end

module Ai
  module ActiveContext
    class TestQueue
      include ::ActiveContext::Concerns::Queue
    end
  end
end
