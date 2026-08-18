# frozen_string_literal: true

# Include these shared examples in specs of Replicators that include
# Geo::OrgMigrationRepositoryReplicatorConcern.
#
# Required let variables:
#
# - replicator:   The replicator under test.
# - model_record: A valid, persisted instance of the replicator's model class
#                 (only required by examples that exercise shard_id).
#
RSpec.shared_examples 'a replicator that does not assign storage outside org migration target cells' do
  context 'when not an org migration target' do
    before do
      stub_feature_flags(org_migration_target_cell: false)
    end

    it 'is a no-op' do
      expect(replicator).not_to receive(:org_migration_storage_ready?)
      replicator.assign_org_migration_storage!
    end
  end
end

RSpec.shared_examples 'an org_migration_storage_ready? check based on shard_id' do
  it 'returns false when shard_id is nil' do
    model_record.update_column(:shard_id, nil)
    expect(replicator.org_migration_storage_ready?).to be false
  end

  it 'returns true when shard_id is present' do
    expect(model_record.shard_id).to be_present
    expect(replicator.org_migration_storage_ready?).to be true
  end
end

RSpec.shared_examples 'a replicator with default no-op track_repository_after_org_migration!' do
  describe '#track_repository_after_org_migration!' do
    it 'is a no-op' do
      expect { replicator.track_repository_after_org_migration! }.not_to raise_error
    end
  end
end
