# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::OrgMigrationRepositoryReplicatorConcern, feature_category: :geo_replication do
  let(:replicator_class) do
    Class.new do
      include Geo::OrgMigrationRepositoryReplicatorConcern
    end
  end

  subject(:replicator) { replicator_class.new }

  describe '#org_migration_storage_ready?' do
    it 'returns true by default' do
      expect(replicator.org_migration_storage_ready?).to be(true)
    end
  end

  describe '#assign_org_migration_storage!' do
    it 'is a no-op' do
      expect { replicator.assign_org_migration_storage! }.not_to raise_error
    end
  end

  describe '#track_repository_after_org_migration!' do
    it 'is a no-op' do
      expect { replicator.track_repository_after_org_migration! }.not_to raise_error
    end
  end

  describe 'PLACEHOLDER_STORAGE' do
    it 'is reset_storage' do
      expect(described_class::PLACEHOLDER_STORAGE).to eq('reset_storage')
    end
  end
end
