# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Cache::Remote::Entry, :aggregate_failures, feature_category: :virtual_registry do
  subject(:cache_entry) { build(:virtual_registries_container_cache_remote_entry) }

  it { is_expected.to include_module(FileStoreMounter) }
  it { is_expected.to include_module(::UpdateNamespaceStatistics) }
  it { is_expected.to include_module(::Auditable) }

  it_behaves_like 'having unique enum values'
  it_behaves_like 'updates namespace statistics' do
    let(:statistic_source) { cache_entry }
    let(:non_statistic_attribute) { :relative_path }
  end

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), cache_entry)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:group).required(true) }
    it { is_expected.to belong_to(:upstream).required(true) }
  end

  describe 'validations' do
    context 'with a non top-level group' do
      let(:subgroup) { build(:group, parent: build(:group)) }
      let(:entry) { build(:virtual_registries_container_cache_remote_entry, group: subgroup) }

      it 'is invalid' do
        expect(entry).to be_invalid
        expect(entry.errors[:group]).to include('must be a top level Group')
      end
    end

    %i[file file_sha1 relative_path size].each do |attr|
      it { is_expected.to validate_presence_of(attr) }
    end

    %i[upstream_etag content_type].each do |attr|
      it { is_expected.to validate_length_of(attr).is_at_most(255) }
    end

    %i[relative_path object_storage_key].each do |attr|
      it { is_expected.to validate_length_of(attr).is_at_most(1024) }
    end

    it { is_expected.to validate_length_of(:file_sha1).is_equal_to(40) }

    context 'with persisted cache entry' do
      before do
        cache_entry.save!
      end

      it { is_expected.to validate_uniqueness_of(:relative_path).scoped_to(:upstream_id, :status) }
      it { is_expected.to validate_uniqueness_of(:object_storage_key).scoped_to(:relative_path, :group_id) }

      context 'with a similar cache entry in a different status' do
        let!(:cache_entry_in_error) do
          create(
            :virtual_registries_container_cache_remote_entry,
            :error,
            group_id: cache_entry.group_id,
            upstream_id: cache_entry.upstream_id,
            relative_path: cache_entry.relative_path
          )
        end

        let(:new_cache_entry) do
          build(
            :virtual_registries_container_cache_remote_entry,
            :error,
            group_id: cache_entry.group_id,
            upstream_id: cache_entry.upstream_id,
            relative_path: cache_entry.relative_path
          )
        end

        before do
          new_cache_entry.validate
        end

        it 'does not validate uniqueness of relative_path' do
          expect(new_cache_entry.errors.messages_for(:relative_path)).not_to include 'has already been taken'
        end
      end
    end
  end

  describe 'scopes' do
    let_it_be(:cache_entry1) { create(:virtual_registries_container_cache_remote_entry) }
    let_it_be(:cache_entry2) { create(:virtual_registries_container_cache_remote_entry) }
    let_it_be(:cache_entry3) { create(:virtual_registries_container_cache_remote_entry) }

    describe '.for_group' do
      let(:groups) { [cache_entry1.group, cache_entry2.group] }

      subject { described_class.for_group(groups) }

      it { is_expected.to contain_exactly(cache_entry1, cache_entry2) }
    end

    describe '.for_upstream' do
      let(:upstreams) { [cache_entry1.upstream, cache_entry2.upstream] }

      subject { described_class.for_upstream(upstreams) }

      it { is_expected.to contain_exactly(cache_entry1, cache_entry2) }
    end

    describe '.requiring_cleanup' do
      let(:n_days_to_keep) { 30 }
      let_it_be(:old_downloaded_entry) do
        create(:virtual_registries_container_cache_remote_entry).tap do |entry|
          entry.update_column(:downloaded_at, 35.days.ago)
        end
      end

      let_it_be(:recent_downloaded_entry) do
        create(:virtual_registries_container_cache_remote_entry).tap do |entry|
          entry.update_column(:downloaded_at, 25.days.ago)
        end
      end

      subject { described_class.requiring_cleanup(n_days_to_keep) }

      it { is_expected.to include(old_downloaded_entry).and not_include(recent_downloaded_entry) }
    end

    describe '.order_iid_desc' do
      subject { described_class.order_iid_desc }

      it { is_expected.to eq([cache_entry3, cache_entry2, cache_entry1].sort_by(&:iid).reverse) }
    end
  end

  describe '.next_pending_destruction' do
    subject { described_class.next_pending_destruction }

    let_it_be_with_reload(:cache_entry) { create(:virtual_registries_container_cache_remote_entry) }
    let_it_be(:pending_destruction_cache_entry) do
      create(:virtual_registries_container_cache_remote_entry, :pending_destruction)
    end

    it { is_expected.to eq(pending_destruction_cache_entry) }
  end

  describe '.search_by_relative_path' do
    let_it_be_with_reload(:cache_entry) { create(:virtual_registries_container_cache_remote_entry) }
    let_it_be(:other_cache_entry) do
      create(:virtual_registries_container_cache_remote_entry, relative_path: 'other/path')
    end

    subject { described_class.search_by_relative_path(relative_path) }

    context 'with a matching relative path' do
      let(:relative_path) { cache_entry.relative_path.slice(3, 8) }

      it { is_expected.to contain_exactly(cache_entry) }
    end
  end

  describe '.create_or_update_by!' do
    let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream) }

    let(:size) { 10.bytes }

    subject(:create_or_update) do
      Tempfile.create('test.txt') do |file|
        file.write('test')
        described_class.create_or_update_by!(
          upstream: upstream,
          group_id: upstream.group_id,
          relative_path: '/test',
          updates: { file: file, size: size, file_sha1: '4e1243bd22c66e76c2ba9eddc1f91394e57f9f95' }
        )
      end
    end

    context 'with invalid updates' do
      let(:size) { nil }

      it 'bubbles up the error' do
        expect { create_or_update }.to not_change { described_class.count }
          .and raise_error(ActiveRecord::RecordInvalid)
      end
    end
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

  describe '#generate_id' do
    let_it_be_with_reload(:upstream) { create(:virtual_registries_container_upstream) }
    let_it_be_with_reload(:cache_entry) { create(:virtual_registries_container_cache_remote_entry, upstream:) }

    let(:expected) { Base64.urlsafe_encode64("#{cache_entry.group_id} #{cache_entry.iid}") }

    subject { cache_entry.generate_id }

    it { is_expected.to eq(expected) }

    context 'for different cache entry' do
      let(:cache_entry2) { create(:virtual_registries_container_cache_remote_entry) }

      it { is_expected.not_to eq(cache_entry2.generate_id) }
    end
  end

  describe '#filename' do
    let(:cache_entry) { build(:virtual_registries_container_cache_remote_entry) }

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
      build(:virtual_registries_container_cache_remote_entry, upstream_checked_at: 10.hours.ago)
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
  end

  describe '#bump_downloads_count' do
    let_it_be_with_reload(:cache_entry) { create(:virtual_registries_container_cache_remote_entry) }

    subject(:bump) { cache_entry.bump_downloads_count }

    it 'enqueues the update', :sidekiq_inline do
      expect(FlushCounterIncrementsWorker)
        .to receive(:perform_in)
        .with(Gitlab::Counters::BufferedCounter::WORKER_DELAY, described_class.name, cache_entry.id, 'downloads_count')
        .and_call_original

      expect { bump }.to change { cache_entry.reload.downloads_count }.by(1)
        .and change { cache_entry.downloaded_at }
    end
  end

  context 'with loose foreign key on virtual_registries_container_cache_remote_entries.upstream_id' do
    it_behaves_like 'update by a loose foreign key' do
      let_it_be_with_reload(:parent) { create(:virtual_registries_container_upstream) }
      let_it_be_with_reload(:model) { create(:virtual_registries_container_cache_remote_entry, upstream: parent) }

      let(:find_model) { described_class.take }
    end
  end

  def with_threads(&block)
    return unless block

    # create a race condition - structure from https://blog.arkency.com/2015/09/testing-race-conditions/
    wait_for_it = true

    threads = Array.new(5) do
      Thread.new do
        # each thread must checkout its own connection
        ApplicationRecord.connection_pool.with_connection do
          # A loop to make threads busy until we `join` them
          true while wait_for_it

          yield
        end
      end
    end

    wait_for_it = false
    threads.each(&:join)
  end
end
