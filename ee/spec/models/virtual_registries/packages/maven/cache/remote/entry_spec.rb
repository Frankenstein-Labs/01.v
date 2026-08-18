# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Cache::Remote::Entry, :aggregate_failures, feature_category: :virtual_registry do
  subject(:cache_entry) { build(:virtual_registries_packages_maven_cache_remote_entry) }

  it { is_expected.to include_module(FileStoreMounter) }
  it { is_expected.to include_module(::UpdateNamespaceStatistics) }
  it { is_expected.to include_module(::Auditable) }

  it_behaves_like 'a remote virtual registry object'

  it_behaves_like 'updates namespace statistics' do
    let(:statistic_source) { cache_entry }
    let(:non_statistic_attribute) { :relative_path }
  end

  it_behaves_like 'virtual registries remote entries models',
    upstream_class: 'VirtualRegistries::Packages::Maven::Upstream',
    upstream_factory: :virtual_registries_packages_maven_upstream,
    entry_factory: :virtual_registries_packages_maven_cache_remote_entry,
    inverted_cache_association_name: :cache_entries

  describe 'declarative policy' do
    it 'delegates to RegistryPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), cache_entry)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end

  describe 'scopes' do
    let_it_be(:cache_entry1) { create(:virtual_registries_packages_maven_cache_remote_entry) }
    let_it_be(:cache_entry2) { create(:virtual_registries_packages_maven_cache_remote_entry) }
    let_it_be(:cache_entry3) { create(:virtual_registries_packages_maven_cache_remote_entry) }

    describe '.for_upstream' do
      let(:upstreams) { [cache_entry1.upstream, cache_entry2.upstream] }

      subject { described_class.for_upstream(upstreams) }

      it { is_expected.to contain_exactly(cache_entry1, cache_entry2) }
    end

    describe '.requiring_cleanup' do
      let(:n_days_to_keep) { 30 }
      let_it_be(:old_downloaded_entry) do
        create(:virtual_registries_packages_maven_cache_remote_entry).tap do |entry|
          entry.update_column(:downloaded_at, 35.days.ago)
        end
      end

      let_it_be(:recent_downloaded_entry) do
        create(:virtual_registries_packages_maven_cache_remote_entry).tap do |entry|
          entry.update_column(:downloaded_at, 25.days.ago)
        end
      end

      subject { described_class.requiring_cleanup(n_days_to_keep) }

      it { is_expected.to include(old_downloaded_entry).and not_include(recent_downloaded_entry) }
    end
  end

  describe '.next_pending_destruction' do
    subject { described_class.next_pending_destruction }

    let_it_be(:cache_entry) { create(:virtual_registries_packages_maven_cache_remote_entry) }
    let_it_be(:pending_destruction_cache_entry) do
      create(:virtual_registries_packages_maven_cache_remote_entry, :pending_destruction)
    end

    it { is_expected.to eq(pending_destruction_cache_entry) }
  end

  describe 'object storage key' do
    it 'can not be null' do
      cache_entry.object_storage_key = nil
      cache_entry.relative_path = nil
      cache_entry.upstream = nil

      is_expected.to be_invalid
      expect(cache_entry.errors.to_a).to include("Object storage key can't be blank")
    end

    it 'can not be too large' do
      cache_entry.object_storage_key = 'a' * 1025
      cache_entry.relative_path = nil

      is_expected.to be_invalid
      expect(cache_entry.errors.to_a).to include('Object storage key is too long (maximum is 1024 characters)')
    end

    it 'is set before saving' do
      expect { cache_entry.save! }
        .to change { cache_entry.object_storage_key }.from(nil).to(an_instance_of(String))
    end

    context 'with a persisted cached response' do
      let(:key) { cache_entry.object_storage_key }

      before do
        cache_entry.save!
      end

      it 'does not change after an update' do
        expect(key).to be_present

        cache_entry.update!(
          file: CarrierWaveStringFile.new('test'),
          size: 2.kilobytes
        )

        expect(cache_entry.object_storage_key).to eq(key)
      end

      it 'is read only' do
        expect(key).to be_present

        cache_entry.object_storage_key = 'new-key'
        cache_entry.save!

        expect(cache_entry.reload.object_storage_key).to eq(key)
      end
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

  describe '#filename' do
    let(:cache_entry) { build(:virtual_registries_packages_maven_cache_remote_entry) }

    subject { cache_entry.filename }

    it { is_expected.to eq(File.basename(cache_entry.relative_path)) }

    context 'when relative_path is nil' do
      before do
        cache_entry.relative_path = nil
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#stale?' do
    let(:cache_entry) do
      build(:virtual_registries_packages_maven_cache_remote_entry, upstream_checked_at: 10.hours.ago)
    end

    subject { cache_entry.stale? }

    shared_examples 'threshold behavior' do
      context 'when before the threshold' do
        before do
          travel_to(threshold - 1.hour)
        end

        it { is_expected.to be(false) }
      end

      context 'when on the threshold' do
        before do
          travel_to(threshold)
        end

        it { is_expected.to be(false) }
      end

      context 'when after the threshold' do
        before do
          travel_to(threshold + 1.hour)
        end

        it { is_expected.to be(true) }
      end
    end

    context 'with no upstream' do
      before do
        cache_entry.upstream = nil
      end

      it { is_expected.to be(true) }
    end

    context 'for regular artifacts' do
      let(:threshold) { cache_entry.upstream_checked_at + cache_entry.upstream.cache_validity_hours.hours }

      include_examples 'threshold behavior'

      context 'with 0 cache validity hours' do
        before do
          cache_entry.upstream.cache_validity_hours = 0
        end

        it { is_expected.to be(false) }
      end
    end

    context 'for metadata file' do
      let(:threshold) { cache_entry.upstream_checked_at + cache_entry.upstream.metadata_cache_validity_hours.hours }

      before do
        cache_entry.relative_path = 'com/company/maven-metadata.xml'
        cache_entry.upstream.cache_validity_hours = 0
      end

      include_examples 'threshold behavior'
    end
  end
end
