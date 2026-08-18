# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Registry, feature_category: :virtual_registry do
  subject(:registry) { build(:virtual_registries_container_registry) }

  describe 'associations', :aggregate_failures do
    it { is_expected.to belong_to(:group) }

    it 'has many registry upstream' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Container::RegistryUpstream')
        .inverse_of(:registry)
    end

    it 'has many upstreams' do
      is_expected.to have_many(:upstreams)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Container::Upstream')
    end
  end

  describe 'validations', :aggregate_failures do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:group_id) }
  end

  describe '.for_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:registry) { create(:virtual_registries_container_registry, group: group) }
    let_it_be(:other_registry) { create(:virtual_registries_container_registry) }

    subject { described_class.for_group(group) }

    it { is_expected.to eq([registry]) }
  end

  describe '#purge_cache!' do
    let_it_be(:registry1) { create(:virtual_registries_container_registry) }
    let_it_be(:registry2) { create(:virtual_registries_container_registry) }
    let_it_be(:upstream1) { create(:virtual_registries_container_upstream, registries: [registry1, registry2]) }
    let_it_be(:upstream2) { create(:virtual_registries_container_upstream, registries: [registry1]) }

    it 'bulk enqueues the MarkEntriesForDestructionWorker' do
      expect(::VirtualRegistries::Cache::MarkEntriesForDestructionWorker)
        .to receive(:bulk_perform_async_with_contexts)
        .with([upstream2], arguments_proc: kind_of(Proc), context_proc: kind_of(Proc))

      registry1.purge_cache!
    end
  end

  it_behaves_like 'virtual registries: upstreams ordering',
    registry_factory: :virtual_registries_container_registry,
    upstream_factory: :virtual_registries_container_upstream

  it_behaves_like 'virtual registries: group registry limit', registry_factory: :virtual_registries_container_registry

  it_behaves_like 'virtual registries: has exclusive upstreams',
    registry_factory: :virtual_registries_container_registry,
    upstream_factory: :virtual_registries_container_upstream

  it_behaves_like 'virtual registries: registry destruction',
    registry_factory: :virtual_registries_container_registry,
    upstream_factory: :virtual_registries_container_upstream,
    registry_upstream_factory: :virtual_registries_container_registry_upstream,
    upstream_class: VirtualRegistries::Container::Upstream,
    registry_upstream_class: VirtualRegistries::Container::RegistryUpstream

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), registry)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
