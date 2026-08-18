# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BaseRegistrySyncWorker, :geo, feature_category: :geo_replication do
  include ::EE::GeoHelpers

  let_it_be(:secondary) { create(:geo_node) }

  before do
    stub_current_geo_node(secondary)
  end

  describe '#schedule_job' do
    let(:worker) { Geo::RegistrySyncWorker.new }
    let(:replicable_name) { 'package_file' }
    let(:model_record_id) { 123 }

    context 'with valid replicator' do
      it 'sets status_expiration based on replicator sync_timeout' do
        expected_expiration = Geo::PackageFileReplicator.status_expiration

        expect(::Geo::SyncWorker)
          .to receive(:set)
                .with(status_expiration: expected_expiration)
                .and_return(::Geo::SyncWorker)

        expect(::Geo::SyncWorker)
          .to receive(:perform_async)
                .with(replicable_name, model_record_id)
                .and_return('job_id_123')

        result = worker.send(:schedule_job, replicable_name, model_record_id)

        expect(result).to eq({
          model_record_id: model_record_id,
          replicable_name: replicable_name,
          job_id: 'job_id_123'
        })
      end

      it 'returns nil when perform_async returns nil' do
        allow(::Geo::SyncWorker).to receive_messages(set: ::Geo::SyncWorker, perform_async: nil)

        result = worker.send(:schedule_job, replicable_name, model_record_id)

        expect(result).to be_nil
      end

      it 'uses different timeouts for different replicators' do
        upload_expiration = Geo::UploadReplicator.status_expiration
        package_expiration = Geo::PackageFileReplicator.status_expiration

        expect(upload_expiration).to eq(8.hours.to_i)
        expect(package_expiration).to eq(8.hours.to_i)
      end
    end
  end

  describe '#status_expiration_for' do
    let(:worker) { Geo::RegistrySyncWorker.new }

    it 'returns 8 hours for upload replicator' do
      expect(worker.send(:status_expiration_for, 'upload')).to eq(8.hours.to_i)
    end

    it 'returns 8 hours for package_file replicator' do
      expect(worker.send(:status_expiration_for, 'package_file')).to eq(8.hours.to_i)
    end

    it 'returns 8 hours for container_repository replicator' do
      expect(worker.send(:status_expiration_for, 'container_repository')).to eq(8.hours.to_i)
    end

    it 'returns an integer' do
      result = worker.send(:status_expiration_for, 'upload')
      expect(result).to be_a(Integer)
    end

    context 'when replicator lookup raises unexpected error' do
      it 'allows the error to propagate' do
        allow(Gitlab::Geo::Replicator)
          .to receive(:for_replicable_name)
                .and_raise(StandardError.new("Unexpected error"))

        expect do
          worker.send(:status_expiration_for, 'upload')
        end.to raise_error(StandardError, "Unexpected error")
      end
    end
  end
end
