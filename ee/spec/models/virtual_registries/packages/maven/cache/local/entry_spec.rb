# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Cache::Local::Entry, feature_category: :virtual_registry do
  subject(:cache_entry) { build(:virtual_registries_packages_maven_cache_local_entry) }

  describe 'declarative policy' do
    it 'delegates to RegistryPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), cache_entry)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end

  describe 'associations' do
    it 'belongs to a group' do
      is_expected.to belong_to(:group).class_name('Group')
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Maven::Local::Upstream')
        .required
        .inverse_of(:cache_entries)
    end

    it 'belongs to a package file' do
      is_expected.to belong_to(:package_file)
        .class_name('Packages::PackageFile')
        .required
    end
  end

  describe 'validations' do
    context 'with a non top-level group' do
      let(:subgroup) { build(:group, parent: build(:group)) }

      subject(:entry) { build(:virtual_registries_packages_maven_cache_local_entry, group: subgroup) }

      it 'is invalid' do
        expect(entry).to be_invalid
        expect(entry.errors[:group]).to include('must be a top level Group')
      end
    end

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:relative_path) }
    it { is_expected.to validate_presence_of(:upstream_checked_at) }
    it { is_expected.to validate_length_of(:relative_path).is_at_most(1024) }
    it { is_expected.to allow_value('foo/bar').for(:relative_path) }
    it { is_expected.not_to allow_value('foo/ bar').for(:relative_path) }

    context 'with a persisted entry' do
      subject(:cache_entry) { create(:virtual_registries_packages_maven_cache_local_entry) }

      it { is_expected.to validate_uniqueness_of(:relative_path).scoped_to([:upstream_id, :group_id]) }
    end
  end

  describe 'delegated methods' do
    it { is_expected.to delegate_method(:file_sha1).to(:package_file).allow_nil }
    it { is_expected.to delegate_method(:file_md5).to(:package_file).allow_nil }
    it { is_expected.to delegate_method(:file).to(:package_file).allow_nil }
  end

  describe 'scopes' do
    let_it_be(:cache_entry1) { create(:virtual_registries_packages_maven_cache_local_entry) }
    let_it_be(:cache_entry2) { create(:virtual_registries_packages_maven_cache_local_entry) }
    let_it_be(:cache_entry3) { create(:virtual_registries_packages_maven_cache_local_entry) }

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

    describe '.preload_package_file' do
      subject(:entries) { described_class.preload_package_file }

      it 'preloads package_file' do
        expect(entries).to all(satisfy { |e| e.association(:package_file).loaded? })
      end
    end
  end

  describe '#stale?' do
    let_it_be(:upstream) { create(:virtual_registries_packages_maven_local_upstream, cache_validity_hours: 24) }

    subject { cache_entry.stale? }

    context 'when upstream_checked_at is recent' do
      let(:cache_entry) do
        build(:virtual_registries_packages_maven_cache_local_entry, upstream: upstream, upstream_checked_at: 1.hour.ago)
      end

      it { is_expected.to be false }
    end

    context 'when upstream_checked_at is old' do
      let(:cache_entry) do
        build(
          :virtual_registries_packages_maven_cache_local_entry,
          upstream: upstream,
          upstream_checked_at: 25.hours.ago
        )
      end

      it { is_expected.to be true }
    end

    context 'when cache_validity_hours is 0' do
      let_it_be(:upstream_never_stale) do
        create(:virtual_registries_packages_maven_local_upstream, cache_validity_hours: 0)
      end

      let(:cache_entry) do
        build(
          :virtual_registries_packages_maven_cache_local_entry,
          upstream: upstream_never_stale,
          upstream_checked_at: 1.year.ago
        )
      end

      it { is_expected.to be false }
    end

    context 'with a maven-metadata.xml path' do
      let_it_be(:upstream_metadata) do
        create(:virtual_registries_packages_maven_local_upstream, metadata_cache_validity_hours: 2)
      end

      let(:cache_entry) do
        build(
          :virtual_registries_packages_maven_cache_local_entry,
          upstream: upstream_metadata,
          relative_path: '/com/test/maven-metadata.xml',
          upstream_checked_at: 3.hours.ago
        )
      end

      it { is_expected.to be true }
    end

    context 'when upstream is nil' do
      let(:cache_entry) do
        build(:virtual_registries_packages_maven_cache_local_entry, upstream_checked_at: 1.hour.ago)
      end

      before do
        allow(cache_entry).to receive(:upstream).and_return(nil)
      end

      it { is_expected.to be true }
    end
  end

  describe '#content_type' do
    subject { cache_entry.content_type }

    it { is_expected.to eq(cache_entry.file.content_type) }
  end

  it_behaves_like 'a local virtual registry object'
end
