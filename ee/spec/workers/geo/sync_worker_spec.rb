# frozen_string_literal: true

require "spec_helper"

RSpec.describe Geo::SyncWorker, :geo, feature_category: :geo_replication do
  subject(:worker) { described_class.new }

  describe 'sidekiq options' do
    it 'does not set status_expiration at class level' do
      expect(described_class.sidekiq_options['status_expiration']).to be_nil
    end

    it 'sets retry to false' do
      expect(described_class.sidekiq_options['retry']).to be false
    end

    it 'sets dead to false' do
      expect(described_class.sidekiq_options['dead']).to be false
    end
  end

  describe "#perform" do
    let(:replicable_name) { 'package_file' }
    let(:model_record_id) { 1 }
    let(:job_args) { [replicable_name, model_record_id] }
    let(:sync_service) { instance_double(::Geo::SyncService) }

    before do
      allow(sync_service).to receive(:execute)
      allow(::Geo::SyncService).to receive(:new).with(*job_args).at_least(1).time.and_return(sync_service)
    end

    it_behaves_like 'an idempotent worker' do
      it "calls Geo::SyncService" do
        expect(sync_service).to receive(:execute).exactly(worker_exec_times).times

        perform_idempotent_work
      end
    end

    it 'uses a different correlation_id than the parent' do
      parent_correlation_id = 'parent-123'
      captured_correlation_id = nil

      allow(::Geo::SyncService).to receive(:new) do |*_args|
        captured_correlation_id = Labkit::Correlation::CorrelationId.current_id
        sync_service
      end

      Labkit::Correlation::CorrelationId.use_id(parent_correlation_id) do
        worker.perform(replicable_name, model_record_id)
      end

      expect(captured_correlation_id).not_to eq(parent_correlation_id)
      expect(captured_correlation_id).to be_present
    end

    it 'logs the correlation_id transition' do
      parent_correlation_id = 'parent-123'

      Labkit::Correlation::CorrelationId.use_id(parent_correlation_id) do
        expect(Gitlab::Geo::Logger).to receive(:info).with(
          hash_including(
            message: 'Sync starting with new correlation_id for filtering',
            replicable_name: replicable_name,
            model_record_id: model_record_id,
            parent_correlation_id: parent_correlation_id
          )
        )

        worker.perform(replicable_name, model_record_id)
      end
    end

    it 'includes the new correlation_id in the log message' do
      parent_correlation_id = 'parent-123'
      logged_data = nil

      allow(Gitlab::Geo::Logger).to receive(:info) do |data|
        logged_data = data
      end

      Labkit::Correlation::CorrelationId.use_id(parent_correlation_id) do
        worker.perform(replicable_name, model_record_id)
      end

      expect(logged_data[:correlation_id]).to be_present
      expect(logged_data[:correlation_id]).not_to eq(parent_correlation_id)
      expect(logged_data[:parent_correlation_id]).to eq(parent_correlation_id)
    end
  end

  describe 'integration with SidekiqStatus' do
    include EE::GeoHelpers

    let(:secondary) { create(:geo_node) }
    let(:package_file) { create(:package_file) }
    let(:replicable_name) { 'package_file' }
    let(:model_record_id) { package_file.id }

    before do
      stub_current_geo_node(secondary)
    end

    context 'when enqueued with explicit status_expiration' do
      it 'creates SidekiqStatus tracking with correct expiration', :clean_gitlab_redis_queues_metadata do
        status_expiration = 100

        jid = described_class.set(status_expiration: status_expiration).perform_async(replicable_name, model_record_id)

        expect(Gitlab::SidekiqStatus.running_or_enqueued?(jid)).to be true
      end

      it 'uses 8 hours when set to replicator timeout', :clean_gitlab_redis_queues_metadata do
        status_expiration = Geo::PackageFileReplicator.status_expiration

        jid = described_class.set(status_expiration: status_expiration).perform_async(replicable_name, model_record_id)

        expect(Gitlab::SidekiqStatus.running_or_enqueued?(jid)).to be true
      end
    end

    context 'when enqueued without status_expiration' do
      it 'does not create SidekiqStatus tracking', :clean_gitlab_redis_queues_metadata do
        jid = described_class.perform_async(replicable_name, model_record_id)

        expect(Gitlab::SidekiqStatus.running_or_enqueued?(jid)).to be false
      end
    end
  end
end
