# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Npm::RegistryUpstream, feature_category: :virtual_registry do
  subject(:registry_upstream) { build(:virtual_registries_packages_npm_registry_upstream) }

  describe 'associations', :aggregate_failures do
    it { is_expected.to belong_to(:group) }

    it 'belongs to a registry' do
      is_expected.to belong_to(:registry)
        .class_name('VirtualRegistries::Packages::Npm::Registry')
        .inverse_of(:registry_upstreams)
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Npm::Upstream')
        .inverse_of(:registry_upstreams)
    end
  end

  describe 'validations', :aggregate_failures do
    subject(:registry_upstream) { create(:virtual_registries_packages_npm_registry_upstream) }

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_uniqueness_of(:upstream_id).scoped_to(:registry_id) }

    it 'validates position' do
      is_expected.to validate_numericality_of(:position)
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(20)
        .only_integer
    end

    # position is set before validation on create. Thus, we need to check the registry_id uniqueness validation
    # manually with two records that are already persisted.
    context 'for registry_id uniqueness' do
      let_it_be_with_reload(:other_registry_upstream) { create(:virtual_registries_packages_npm_registry_upstream) }

      it 'validates it' do
        other_registry_upstream.assign_attributes(registry_upstream.attributes)

        expect(other_registry_upstream.valid?).to be_falsey
        expect(other_registry_upstream.errors[:registry_id].first).to eq('has already been taken')
      end
    end
  end

  it_behaves_like 'registry upstream position sync',
    registry_factory: :virtual_registries_packages_npm_registry,
    registry_upstream_factory: :virtual_registries_packages_npm_registry_upstream

  it_behaves_like 'registry upstream registries count',
    upstream_factory: :virtual_registries_packages_npm_upstream,
    registry_factory: :virtual_registries_packages_npm_registry,
    registry_upstream_factory: :virtual_registries_packages_npm_registry_upstream

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), registry_upstream)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
