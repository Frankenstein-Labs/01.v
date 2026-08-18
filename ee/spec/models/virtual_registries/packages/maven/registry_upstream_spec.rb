# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::RegistryUpstream, type: :model, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  subject(:registry_upstream) { build(:virtual_registries_packages_maven_registry_upstream) }

  describe 'associations' do
    it { is_expected.to belong_to(:group) }

    it 'belongs to a registry' do
      is_expected.to belong_to(:registry)
        .class_name('VirtualRegistries::Packages::Maven::Registry')
        .inverse_of(:registry_upstreams)
    end

    it 'belongs to an upstream' do
      is_expected.to belong_to(:upstream)
        .class_name('VirtualRegistries::Packages::Maven::Upstream')
        .inverse_of(:registry_upstreams)
        .optional(true)
    end

    it 'belongs to a local upstream' do
      is_expected.to belong_to(:local_upstream)
        .class_name('VirtualRegistries::Packages::Maven::Local::Upstream')
        .inverse_of(:registry_upstreams)
        .optional(true)
    end
  end

  describe 'validations' do
    subject(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream) }

    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_uniqueness_of(:upstream_id).scoped_to(:registry_id) }

    context 'when targeting a local upstream' do
      subject(:registry_upstream) { create(:virtual_registries_packages_maven_registry_upstream, :with_local_upstream) }

      it { is_expected.to validate_uniqueness_of(:local_upstream_id).scoped_to(:registry_id) }
    end

    it 'validates position' do
      is_expected.to validate_numericality_of(:position)
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(20)
        .only_integer
    end

    # position is set before validation on create. Thus, we need to check the registry_id uniqueness validation
    # manually with two records that are already persisted.
    context 'for registry_id uniqueness' do
      let_it_be_with_reload(:other_registry_upstream) do
        create(:virtual_registries_packages_maven_registry_upstream)
      end

      it 'validates it' do
        other_registry_upstream.assign_attributes(registry_upstream.attributes)

        expect(other_registry_upstream.valid?).to be_falsey
        expect(other_registry_upstream.errors[:registry_id].first).to eq('has already been taken')
      end
    end

    describe '#ensure_upstream_or_local_upstream' do
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream) }
      let_it_be(:other_local_upstream) { create(:virtual_registries_packages_maven_local_upstream) }

      where(:remote_upstream, :local_upstream, :expected_error_messages) do
        nil                  | ref(:other_local_upstream) | []
        ref(:other_upstream) | nil                        | []
        ref(:other_upstream) | ref(:other_local_upstream) | [described_class::UPSTREAMS_MUTUALLY_EXCLUSIVE_ERROR]
        nil                  | nil                        | [described_class::UPSTREAMS_MUTUALLY_EXCLUSIVE_ERROR]
      end

      with_them do
        subject(:upstream) do
          build(
            :virtual_registries_packages_maven_registry_upstream,
            upstream: remote_upstream,
            local_upstream: local_upstream
          )
        end

        if params[:expected_error_messages].any?
          it { is_expected.to be_invalid.and have_attributes(errors: match_array(expected_error_messages)) }
        else
          it { is_expected.to be_valid }
        end
      end
    end
  end

  it_behaves_like 'registry upstream position sync',
    registry_factory: :virtual_registries_packages_maven_registry,
    registry_upstream_factory: :virtual_registries_packages_maven_registry_upstream

  describe '.registries_count_by_upstream_ids' do
    let_it_be(:upstream1) { create(:virtual_registries_packages_maven_upstream) }
    let_it_be(:upstream2) { create(:virtual_registries_packages_maven_upstream) }
    let_it_be(:upstream3) { create(:virtual_registries_packages_maven_upstream) }

    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }

    let_it_be(:registry_upstream1) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry1, upstream: upstream1)
    end

    let_it_be(:registry_upstream2) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry2, upstream: upstream1)
    end

    let_it_be(:registry_upstream3) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry1, upstream: upstream2)
    end

    it 'returns count of registries grouped by upstream_id' do
      result = described_class.registries_count_by_upstream_ids([upstream1.id, upstream2.id, upstream3.id])

      expect(result).to eq(upstream1.id => 3, upstream2.id => 2, upstream3.id => 1)
    end

    it 'returns empty hash when no upstream_ids match' do
      result = described_class.registries_count_by_upstream_ids([999])

      expect(result).to eq({})
    end

    it 'returns empty hash when upstream_ids array is empty' do
      result = described_class.registries_count_by_upstream_ids([])

      expect(result).to eq({})
    end
  end

  describe 'declarative policy' do
    it 'delegates to GroupPolicy' do
      policy = DeclarativePolicy.policy_for(build(:user), registry_upstream)

      expect(policy).to be_a(VirtualRegistries::Policies::GroupPolicy)
    end
  end
end
