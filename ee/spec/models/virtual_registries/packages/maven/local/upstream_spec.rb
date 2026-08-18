# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Local::Upstream, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:other_project) { create(:project) }
  let_it_be(:other_group) { create(:group) }

  subject(:upstream) { build(:virtual_registries_packages_maven_local_upstream) }

  it 'has GroupPolicy as declarative policy' do
    expect(described_class.declarative_policy_class).to eq('VirtualRegistries::Policies::GroupPolicy')
  end

  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'has many cache entries' do
      is_expected.to have_many(:cache_entries)
        .class_name('VirtualRegistries::Packages::Maven::Cache::Local::Entry')
        .inverse_of(:upstream)
    end

    it 'has many registry upstreams' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::RegistryUpstream')
        .inverse_of(:local_upstream)
        .autosave(true)
    end

    it 'has many registries' do
      is_expected.to have_many(:registries)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::Registry')
    end

    it 'belongs to a local project' do
      is_expected.to belong_to(:local_project)
        .class_name('Project')
        .optional(true)
    end

    it 'belongs to a local group' do
      is_expected.to belong_to(:local_group)
        .class_name('Group')
        .optional(true)
    end
  end

  describe 'validations' do
    context 'with a non top-level group' do
      let(:subgroup) { build(:group, parent: build(:group)) }

      subject(:upstream) { build(:virtual_registries_packages_maven_local_upstream, group: subgroup) }

      it 'is invalid' do
        expect(upstream).to be_invalid
        expect(upstream.errors[:group]).to include('must be a top level Group')
      end
    end

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
    it { is_expected.to validate_numericality_of(:cache_validity_hours).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:metadata_cache_validity_hours).only_integer.is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:local_project_id).scoped_to(:group_id) }

    context 'with a local group upstream' do
      subject(:upstream) do
        build(:virtual_registries_packages_maven_local_upstream, :local_group, registries: [], group: create(:group))
      end

      it { is_expected.to validate_uniqueness_of(:local_group_id).scoped_to(:group_id) }
    end

    describe '#ensure_local_project_or_local_group' do
      where(:local_project, :local_group, :expected_error_messages) do
        nil                 | ref(:other_group) | []
        ref(:other_project) | nil               | []
        ref(:other_project) | ref(:other_group) | ['should only have either the local group or local project set']
        nil                 | nil               | ['should only have either the local group or local project set']
      end

      with_them do
        subject(:upstream) do
          build(:virtual_registries_packages_maven_local_upstream, local_project:, local_group:)
        end

        if params[:expected_error_messages].any?
          it { is_expected.to be_invalid.and have_attributes(errors: match_array(expected_error_messages)) }
        else
          it { is_expected.to be_valid }
        end
      end
    end
  end

  describe 'scopes' do
    describe '.for_id_and_group' do
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_local_upstream) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_local_upstream) }

      subject { described_class.for_id_and_group(id: upstream.id, group: upstream.group) }

      it { is_expected.to contain_exactly(upstream) }
    end

    describe '.for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_local_upstream, group:) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_local_upstream) }

      subject { described_class.for_group(group) }

      it { is_expected.to contain_exactly(upstream) }
    end

    describe '.search_by_name' do
      let(:query) { 'abc' }
      let_it_be(:name) { 'pkg-name-abc' }
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_local_upstream, name: name) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_local_upstream) }

      subject { described_class.search_by_name(query) }

      it { is_expected.to contain_exactly(upstream) }
    end

    describe '.eager_load_registry_upstream' do
      let_it_be(:group) { create(:group) }
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, group: group) }
      let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry, group: group, name: 'other') }
      let_it_be(:upstream1) { create(:virtual_registries_packages_maven_local_upstream, group: group) }
      let_it_be(:upstream2) { create(:virtual_registries_packages_maven_local_upstream, group: group) }
      let_it_be(:ru1) do
        create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream,
          registry: registry, local_upstream: upstream1)
      end

      let_it_be(:ru2) do
        create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream,
          registry: registry, local_upstream: upstream2)
      end

      let_it_be(:other_ru) do
        create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream,
          registry: other_registry, local_upstream: upstream1)
      end

      it 'returns upstreams for the given registry ordered by position' do
        result = described_class.eager_load_registry_upstream(registry: registry)

        expect(result).to contain_exactly(upstream1, upstream2)
        expect(result.map { |u| u.registry_upstreams.first.position }).to eq([1, 2])
      end

      it 'does not include upstreams from other registries' do
        result = described_class.eager_load_registry_upstream(registry: registry)

        expect(result.flat_map(&:registry_upstreams).map(&:registry_id).uniq).to eq([registry.id])
      end
    end
  end

  describe '#destroy_and_sync_positions' do
    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry1_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream, registry: registry1)
    end

    let_it_be(:other_registry1_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream, registry: registry1)
    end

    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2_upstream) do
      create(
        :virtual_registries_packages_maven_registry_upstream,
        :with_local_upstream,
        registry: registry2,
        local_upstream: registry1_upstream.local_upstream
      )
    end

    let_it_be(:other_registry2_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream, registry: registry2)
    end

    subject(:destroy_and_sync) { registry1_upstream.local_upstream.destroy_and_sync_positions }

    it 'destroys the upstream and sync the registries positions' do
      expect { destroy_and_sync }.to change { described_class.count }.by(-1)
        .and change { registry1.reload.registry_upstreams.count }.from(2).to(1)
        .and change { registry2.reload.registry_upstreams.count }.from(2).to(1)
        .and change { other_registry1_upstream.reload.position }.from(2).to(1)
        .and change { other_registry2_upstream.reload.position }.from(2).to(1)
    end
  end

  it_behaves_like 'a local virtual registry object'
end
