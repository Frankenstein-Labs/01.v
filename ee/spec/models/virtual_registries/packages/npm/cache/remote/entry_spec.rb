# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::Cache::Remote::Entry, :aggregate_failures, feature_category: :virtual_registry do
  subject(:entry) { build(:virtual_registries_packages_npm_cache_remote_entry) }

  it { is_expected.to include_module(FileStoreMounter) }
  it { is_expected.to include_module(::UpdateNamespaceStatistics) }
  it { is_expected.to include_module(::Auditable) }

  it_behaves_like 'updates namespace statistics' do
    let(:statistic_source) { entry }
    let(:non_statistic_attribute) { :relative_path }
  end

  it_behaves_like 'virtual registries remote entries models',
    upstream_class: 'VirtualRegistries::Packages::Npm::Upstream',
    upstream_factory: :virtual_registries_packages_npm_upstream,
    entry_factory: :virtual_registries_packages_npm_cache_remote_entry

  describe 'validations' do
    context 'with a non top-level group' do
      let(:subgroup) { build(:group, parent: build(:group)) }
      let(:invalid_entry) { build(:virtual_registries_packages_npm_cache_remote_entry, group: subgroup) }

      it 'is invalid' do
        expect(invalid_entry).to be_invalid
        expect(invalid_entry.errors[:group]).to include('must be a top level Group')
      end
    end
  end

  describe 'scopes' do
    let_it_be(:cache_entry1) { create(:virtual_registries_packages_npm_cache_remote_entry) }
    let_it_be(:cache_entry2) { create(:virtual_registries_packages_npm_cache_remote_entry) }

    describe '.for_group' do
      subject { described_class.for_group(cache_entry1.group) }

      it { is_expected.to contain_exactly(cache_entry1) }
    end

    describe '.for_upstream' do
      subject { described_class.for_upstream(cache_entry1.upstream) }

      it { is_expected.to contain_exactly(cache_entry1) }
    end
  end

  describe 'file_store attribute' do
    subject(:file_store) { described_class.new.file_store }

    context 'when object storage is enabled' do
      it 'defaults to remote store' do
        expect(VirtualRegistries::Cache::EntryUploader).to receive(:object_store_enabled?)
          .and_return(true)

        expect(file_store).to eq(ObjectStorage::Store::REMOTE)
      end
    end

    context 'when object storage is disabled' do
      it 'defaults to local store' do
        expect(VirtualRegistries::Cache::EntryUploader).to receive(:object_store_enabled?)
          .and_return(false)

        expect(file_store).to eq(ObjectStorage::Store::LOCAL)
      end
    end
  end

  describe 'object storage key' do
    it 'can not be null' do
      entry.object_storage_key = nil
      entry.relative_path = nil
      entry.upstream = nil

      is_expected.to be_invalid
      expect(entry.errors.to_a).to include("Object storage key can't be blank")
    end

    it 'can not be too large' do
      entry.object_storage_key = 'a' * 1025
      entry.relative_path = nil

      is_expected.to be_invalid
      expect(entry.errors.to_a).to include('Object storage key is too long (maximum is 1024 characters)')
    end

    it 'is set before saving' do
      expect { entry.save! }
        .to change { entry.object_storage_key }.from(nil).to(an_instance_of(String))
    end

    context 'with a persisted cached response' do
      let(:key) { entry.object_storage_key }

      before do
        entry.save!
      end

      it 'does not change after an update' do
        expect(key).to be_present

        entry.update!(
          file: CarrierWaveStringFile.new('test'),
          size: 2.kilobytes
        )

        expect(entry.object_storage_key).to eq(key)
      end

      it 'is read only' do
        expect(key).to be_present

        entry.object_storage_key = 'new-key'
        entry.save!

        expect(entry.reload.object_storage_key).to eq(key)
      end
    end
  end

  describe '#filename' do
    context 'when relative_path is present' do
      it 'returns the basename' do
        entry.relative_path = '/some/path/file.txt'

        expect(entry.filename).to eq('file.txt')
      end
    end

    context 'when relative_path is nil' do
      it 'returns nil' do
        entry.relative_path = nil

        expect(entry.filename).to be_nil
      end
    end
  end

  describe '#stale?' do
    let(:entry) do
      build(:virtual_registries_packages_npm_cache_remote_entry, upstream_checked_at: 10.hours.ago)
    end

    subject { entry.stale? }

    context 'with no upstream' do
      before do
        entry.upstream = nil
      end

      it { is_expected.to be(true) }
    end

    context 'when cache_validity_hours is 0' do
      before do
        entry.upstream.cache_validity_hours = 0
      end

      it { is_expected.to be(false) }
    end

    context 'when before the threshold' do
      before do
        travel_to(entry.upstream_checked_at + entry.upstream.cache_validity_hours.hours - 1.hour)
      end

      it { is_expected.to be(false) }
    end

    context 'when after the threshold' do
      before do
        travel_to(entry.upstream_checked_at + entry.upstream.cache_validity_hours.hours + 1.hour)
      end

      it { is_expected.to be(true) }
    end
  end
end
