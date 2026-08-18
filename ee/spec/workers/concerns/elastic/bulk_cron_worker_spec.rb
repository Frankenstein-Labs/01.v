# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Elastic::BulkCronWorker, feature_category: :global_search do
  include ExclusiveLeaseHelpers

  # Create a test class that includes the concern
  let(:worker_klass) do
    Class.new do
      def self.name
        'TestWorker'
      end

      include Elastic::BulkCronWorker

      def initialize(service)
        @service = service
      end

      attr_reader :service
    end
  end

  let(:service) { instance_double(Elastic::ProcessBookkeepingService) }
  let(:worker) { worker_klass.new(service) }

  describe '#perform' do
    using RSpec::Parameterized::TableSyntax

    # Common setup for all tests
    before do
      stub_ee_application_setting(
        elasticsearch_indexing?: true,
        advanced_search_indexing_paused?: false,
        elasticsearch_requeue_workers?: false
      )

      allow(worker).to receive(:legacy_lock_exists?).and_return(false)
      allow(Search::ClusterHealthCheck::Elastic).to receive(:healthy?).and_return(true)
      allow(worker).to receive(:schedule_shards)
      allow(worker).to receive(:process_shard)
    end

    describe 'precondition checks' do
      where(:es_indexing, :es_paused, :legacy_lock, :cluster_healthy, :shards_processed) do
        true  | false | false | true  | true
        false | false | false | false | false
        true  | false | false | false | false
        true  | true  | false | false | false
        true  | true  | true  | false | false
      end

      with_them do
        before do
          stub_ee_application_setting(
            elasticsearch_indexing?: es_indexing,
            advanced_search_indexing_paused?: es_paused,
            elasticsearch_requeue_workers?: false
          )

          allow(Search::ClusterHealthCheck::Elastic).to receive(:healthy?).and_return(cluster_healthy)
          allow(worker).to receive(:legacy_lock_exists?).and_return(legacy_lock)
        end

        it 'processes shards when preconditions are met' do
          if shards_processed
            expect(worker).to receive(:schedule_shards)
          else
            expect(worker).not_to receive(:schedule_shards)
          end

          worker.perform
        end
      end
    end

    describe 'execution paths' do
      it 'processes the given shard when shard number is provided' do
        worker.perform(1)
        expect(worker).to have_received(:process_shard).with(1)
        expect(worker).not_to have_received(:schedule_shards)
      end

      it 'schedules all shards when no shard number is provided' do
        worker.perform
        expect(worker).to have_received(:schedule_shards)
        expect(worker).not_to have_received(:process_shard)
      end
    end

    describe 'error handling' do
      it 'catches and continues when failing to obtain a lock' do
        stub_exclusive_lease("test_worker/shard/1", 'uuid')

        expect { worker.perform(1) }.not_to raise_error
      end

      it 'logs when the cluster is unhealthy' do
        allow(Search::ClusterHealthCheck::Elastic).to receive(:healthy?).and_return(false)
        expect(worker).to receive(:log).with(/advanced search cluster is unhealthy/)

        worker.perform
      end
    end
  end

  describe '#process_shard' do
    using RSpec::Parameterized::TableSyntax
    let(:shard_number) { 1 }
    let(:lock_name) { "test_worker/shard/#{shard_number}" }
    let(:lock_ttl) { 10.minutes }

    before do
      stub_exclusive_lease(lock_name, 'uuid', timeout: lock_ttl)
      allow(worker).to receive(:log_extra_metadata_on_done)
      allow(worker_klass).to receive(:perform_in)
      allow(service).to receive(:execute).and_return([10, 0])
    end

    subject(:process_shard) { worker.send(:process_shard, shard_number) }

    it 'uses the correct lock name and options' do
      expect(worker).to receive(:in_lock).with(
        lock_name,
        ttl: lock_ttl,
        retries: 10,
        sleep_sec: 1
      ).and_yield

      process_shard
    end

    it 'executes the service with the given shard' do
      process_shard

      expect(service).to have_received(:execute).with(shards: [shard_number])
    end

    it 'logs metadata about the execution' do
      process_shard

      expect(worker).to have_received(:log_extra_metadata_on_done).with(:records_count, 10)
      expect(worker).to have_received(:log_extra_metadata_on_done).with(:shard_number, shard_number)
    end

    where(:records_count, :failures_count, :requeue_workers_enabled, :should_requeue) do
      10  | 0 | true  | true # Requeue when more records and no failures
      0   | 0 | true  | false # Don't requeue when no more records
      10  | 1 | true  | false # Don't requeue when there are failures
      nil | 0 | true  | false # Don't requeue when records_count is nil
      10  | 0 | false | false # Don't requeue when feature is disabled
    end

    with_them do
      it 'handles requeuing correctly' do
        stub_ee_application_setting(elasticsearch_requeue_workers?: requeue_workers_enabled)
        allow(service).to receive(:execute).and_return([records_count, failures_count])

        process_shard

        if should_requeue
          expect(worker_klass).to have_received(:perform_in)
            .with(Elastic::BulkCronWorker::RESCHEDULE_INTERVAL, shard_number)
        else
          expect(worker_klass).not_to have_received(:perform_in)
        end
      end
    end
  end

  describe '#schedule_shards' do
    before do
      stub_const('Elastic::ProcessBookkeepingService::SHARDS', [1, 2, 3])
      allow(worker_klass).to receive(:perform_async)
    end

    it 'schedules a job for each shard' do
      worker.send(:schedule_shards)

      expect(worker_klass).to have_received(:perform_async).with(1)
      expect(worker_klass).to have_received(:perform_async).with(2)
      expect(worker_klass).to have_received(:perform_async).with(3)
    end
  end

  describe '#legacy_lock_exists?' do
    using RSpec::Parameterized::TableSyntax

    where(:uuid_result, :expected_result) do
      'some-uuid' | true # Lock exists
      nil         | false # No lock exists
    end

    with_them do
      it 'correctly determines if a lock exists' do
        expect(Gitlab::ExclusiveLease).to receive(:get_uuid).with('test_worker').and_return(uuid_result)

        expect(worker.send(:legacy_lock_exists?)).to eq(expected_result)
      end
    end
  end

  describe '#should_requeue?' do
    using RSpec::Parameterized::TableSyntax

    where(:records_count, :failures_count, :requeue_workers_enabled, :expected_result) do
      10  | 0 | true  | true # All conditions met
      nil | 0 | true  | false # records_count is nil
      10  | 1 | true  | false # There are failures
      10  | 0 | false | false # Requeuing is disabled
      0   | 0 | true  | false # No more records to process
    end

    with_them do
      before do
        stub_ee_application_setting(elasticsearch_requeue_workers?: requeue_workers_enabled)
      end

      it 'returns the expected result' do
        expect(worker.send(:should_requeue?, records_count: records_count, failures_count: failures_count))
          .to eq(expected_result)
      end
    end
  end
end
