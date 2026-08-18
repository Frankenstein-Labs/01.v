# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCap, feature_category: :seat_cost_management do
  using RSpec::Parameterized::TableSyntax

  describe '.dashboard_limit' do
    subject { described_class.dashboard_limit }

    context 'when set to default' do
      it { is_expected.to eq 0 }
    end

    context 'when not set to default' do
      before do
        stub_ee_application_setting(dashboard_limit: 5)
      end

      it { is_expected.to eq 5 }
    end
  end

  describe '.dashboard_limit_enabled?' do
    let(:dashboard_limit_enabled) { true }

    subject { described_class.dashboard_limit_enabled? }

    before do
      stub_ee_application_setting(dashboard_limit_enabled: dashboard_limit_enabled)
    end

    context 'when set true' do
      it { is_expected.to be(true) }
    end

    context 'when set to false' do
      let(:dashboard_limit_enabled) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '.can_read_billable_members?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    subject(:access) { described_class.can_read_billable_members?(user: user, namespace: namespace) }

    context 'when user is not provided' do
      let(:user) { nil }

      it 'returns false' do
        expect(access).to be(false)
      end
    end

    context 'when the user does not have `read_billable_member` permission' do
      it 'returns false' do
        namespace.add_developer(user)

        expect(access).to be(false)
      end
    end

    context 'when user has owner access' do
      it 'returns true' do
        namespace.add_owner(user)

        expect(access).to be(true)
      end
    end
  end

  describe '.non_owner_access?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    subject(:access) { described_class.non_owner_access?(user: user, namespace: namespace) }

    context 'when user is not provided' do
      let(:user) { nil }

      it 'returns false' do
        expect(access).to be(false)
      end
    end

    context 'when user does not have owner access' do
      it 'returns true' do
        namespace.add_developer(user)

        expect(access).to be(true)
      end
    end

    context 'when user has owner access' do
      it 'returns false' do
        namespace.add_owner(user)

        expect(access).to be(false)
      end
    end
  end

  describe '.enforced_without_storage_check?', :saas do
    let_it_be(:namespace) { create(:group_with_plan) }

    subject(:enforced_without_storage_check) { described_class.enforced_without_storage_check?(namespace) }

    before do
      create(:plan_limits, plan: namespace.gitlab_subscription.hosted_plan, storage_size_limit: 100)
      create(:namespace_root_storage_statistics, namespace: namespace, storage_size: current_size)
    end

    context 'when over the storage limit' do
      let(:current_size) { 101.megabytes }

      it { is_expected.to be(true) }
    end

    context 'when below the storage limit' do
      let(:current_size) { 50.megabytes }

      it { is_expected.to be(false) }
    end

    context 'when the storage check feature flag is disabled' do
      before do
        stub_feature_flags(free_user_cap_without_storage_check: false)
      end

      context 'when over the storage limit' do
        let(:current_size) { 101.megabytes }

        it { is_expected.to be(false) }
      end
    end
  end
end
