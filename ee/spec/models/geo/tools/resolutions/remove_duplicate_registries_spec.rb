# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::Tools::Resolutions::RemoveDuplicateRegistries, :geo, feature_category: :geo_replication do
  let(:error_type) { Geo::Errors::ErrorType.find_by(name: 'duplicate_registries') }
  let_it_be(:package_file) { create(:package_file) }

  subject(:resolution) { described_class.new(error_type) }

  describe '#affected_count' do
    it 'counts the extra rows for duplicated model records' do
      create(:geo_package_file_registry, :synced, package_file: package_file)
      create(:geo_package_file_registry, :failed, package_file: package_file)
      create(:geo_package_file_registry) # unrelated, not duplicated

      expect(resolution.affected_count).to eq(1)
    end

    it 'is zero when there are no duplicates' do
      create(:geo_package_file_registry)

      expect(resolution.affected_count).to eq(0)
    end

    it 'counts duplicates for model records that fall in different batches' do
      stub_const("#{described_class.superclass}::BATCH_SIZE", 1)
      other_package_file = create(:package_file)

      create(:geo_package_file_registry, :synced, package_file: package_file)
      create(:geo_package_file_registry, :failed, package_file: package_file)
      create(:geo_package_file_registry, :synced, package_file: other_package_file)
      create(:geo_package_file_registry, :failed, package_file: other_package_file)

      expect(resolution.affected_count).to eq(2)
    end

    it 'counts a shared registry class only once' do
      allow(Gitlab::Geo).to receive(:replication_enabled_replicator_classes)
        .and_return([Geo::PackageFileReplicator, Geo::PackageFileReplicator])

      create(:geo_package_file_registry, :synced, package_file: package_file)
      create(:geo_package_file_registry, :failed, package_file: package_file)

      expect(resolution.affected_count).to eq(1)
    end
  end

  describe '#apply' do
    it 'keeps the synced row and deletes the duplicates', :aggregate_failures do
      synced = create(:geo_package_file_registry, :synced, package_file: package_file)
      duplicate = create(:geo_package_file_registry, :failed, package_file: package_file)

      expect { resolution.apply }.to change { Geo::PackageFileRegistry.count }.by(-1)
      expect(Geo::PackageFileRegistry.exists?(synced.id)).to be(true)
      expect(Geo::PackageFileRegistry.exists?(duplicate.id)).to be(false)
    end

    it 'respects the limit' do
      create(:geo_package_file_registry, :synced, package_file: package_file)
      create_list(:geo_package_file_registry, 2, :failed, package_file: package_file)

      expect { resolution.apply(limit: 1) }.to change { Geo::PackageFileRegistry.count }.by(-1)
    end

    it 'keeps the most recently created row when none are synced', :aggregate_failures do
      older = create(:geo_package_file_registry, :failed, package_file: package_file)
      newer = create(:geo_package_file_registry, :failed, package_file: package_file)

      expect { resolution.apply }.to change { Geo::PackageFileRegistry.count }.by(-1)
      expect(Geo::PackageFileRegistry.exists?(newer.id)).to be(true)
      expect(Geo::PackageFileRegistry.exists?(older.id)).to be(false)
    end
  end
end
