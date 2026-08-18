# frozen_string_literal: true

# Include these shared examples in specs of registry classes that include
# Geo::Concerns::PartitionUploadRegistry.
#
# Required context: described_class must be the partition upload registry class.
#
RSpec.shared_examples 'a Geo framework partition upload registry' do
  include EE::GeoHelpers

  describe '.registry_consistency_worker_enabled?' do
    context 'when the base Upload replicator is disabled and the partition replicator is enabled' do
      before do
        allow(::Geo::UploadReplicator).to receive(:replication_enabled?).and_return(false)
        allow(described_class.replicator_class).to receive(:replication_enabled?).and_return(true)
      end

      it 'returns true so the consistency worker runs for this registry' do
        expect(described_class.registry_consistency_worker_enabled?).to be(true)
      end
    end

    context 'when the base Upload replicator is enabled' do
      before do
        allow(::Geo::UploadReplicator).to receive(:replication_enabled?).and_return(true)
        allow(described_class.replicator_class).to receive(:replication_enabled?).and_return(true)
      end

      it 'returns false to prevent duplicate registry rows alongside Geo::UploadRegistry' do
        expect(described_class.registry_consistency_worker_enabled?).to be(false)
      end
    end

    context 'when both the base Upload replicator and the partition replicator are disabled' do
      before do
        allow(::Geo::UploadReplicator).to receive(:replication_enabled?).and_return(false)
        allow(described_class.replicator_class).to receive(:replication_enabled?).and_return(false)
      end

      it 'returns false so the consistency worker does not run' do
        expect(described_class.registry_consistency_worker_enabled?).to be(false)
      end
    end
  end
end
