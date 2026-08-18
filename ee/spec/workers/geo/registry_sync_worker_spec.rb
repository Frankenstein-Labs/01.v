# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::RegistrySyncWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be_with_reload(:secondary) { create(:geo_node) }

  it_behaves_like 'a framework registry sync worker', :geo_package_file_registry, :files_max_capacity do
    before do
      result_object = double(
        :result,
        success: true,
        bytes_downloaded: 100,
        primary_missing_file: false,
        reason: '',
        extra_details: {}
      )

      allow_any_instance_of(::Gitlab::Geo::Replication::BlobDownloader).to receive(:execute).and_return(result_object)
    end
  end

  describe '#max_capacity' do
    before do
      stub_current_geo_node(secondary)
      secondary.update!(container_repositories_max_capacity: 3, files_max_capacity: 6, repos_max_capacity: 7)
    end

    it 'returns only files_max_capacity based capacity' do
      expect(subject.send(:max_capacity)).to eq(6)
    end
  end

  describe 'status expiration integration' do
    let_it_be(:package_file) { create(:package_file) }
    let_it_be(:upload) { create(:upload) }

    before do
      stub_current_geo_node(secondary)
    end

    it 'schedules package_file sync with 8 hour status expiration', :clean_gitlab_redis_queues_metadata do
      worker = described_class.new

      result = worker.send(:schedule_job, 'package_file', package_file.id)

      expect(result).to be_present
      expect(result[:job_id]).to be_present
      expect(Gitlab::SidekiqStatus.running_or_enqueued?(result[:job_id])).to be true
    end

    it 'schedules upload sync with 8 hour status expiration', :clean_gitlab_redis_queues_metadata do
      worker = described_class.new

      result = worker.send(:schedule_job, 'upload', upload.id)

      expect(result).to be_present
      expect(result[:job_id]).to be_present
      expect(Gitlab::SidekiqStatus.running_or_enqueued?(result[:job_id])).to be true
    end

    it 'uses correct timeout for different replicator types', :clean_gitlab_redis_queues_metadata do
      worker = described_class.new

      package_result = worker.send(:schedule_job, 'package_file', package_file.id)
      upload_result = worker.send(:schedule_job, 'upload', upload.id)

      expect(Gitlab::SidekiqStatus.running_or_enqueued?(package_result[:job_id])).to be true
      expect(Gitlab::SidekiqStatus.running_or_enqueued?(upload_result[:job_id])).to be true
    end

    it 'sets TTL to approximately 8 hours', :clean_gitlab_redis_queues_metadata do
      worker = described_class.new

      result = worker.send(:schedule_job, 'package_file', package_file.id)
      jid = result[:job_id]

      redis_key = Gitlab::SidekiqStatus.send(:key_for, jid)
      ttl = Gitlab::Redis::QueuesMetadata.with { |redis| redis.ttl(redis_key) }

      expect(ttl).to be_between(28700, 28800)
    end
  end

  describe 'error handling in schedule_job' do
    let_it_be(:package_file) { create(:package_file) }

    before do
      stub_current_geo_node(secondary)
    end

    it 'handles exceptions in status_expiration_for gracefully' do
      worker = described_class.new

      allow(worker).to receive(:status_expiration_for).and_raise(StandardError.new("Test error"))

      expect { worker.send(:schedule_job, 'package_file', package_file.id) }.to raise_error(StandardError, "Test error")
    end
  end
end
