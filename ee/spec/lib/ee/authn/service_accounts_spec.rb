# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Authn::ServiceAccounts, feature_category: :system_access do
  describe '.creation_allowed_for_sm?' do
    context 'when license is ultimate' do
      before do
        allow(::License).to receive(:current).and_return(create(:license, plan: License::ULTIMATE_PLAN))
      end

      it { expect(described_class.creation_allowed_for_sm?).to be(true) }
    end

    context 'when license is premium' do
      before do
        allow(::License).to receive(:current).and_return(create(:license, plan: License::PREMIUM_PLAN))
      end

      it { expect(described_class.creation_allowed_for_sm?).to be(true) }
    end

    context 'when license is starter' do
      before do
        allow(::License).to receive(:current).and_return(create(:license, plan: License::STARTER_PLAN))
      end

      it 'returns true when under the limit' do
        expect(described_class.creation_allowed_for_sm?).to be(true)
      end

      it 'returns false when at the limit' do
        stub_const('Authn::ServiceAccounts::LIMIT_FOR_FREE', 2)
        create_list(:user, 2, :service_account)

        expect(described_class.creation_allowed_for_sm?).to be(false)
      end
    end

    context 'when no license is installed' do
      before do
        allow(::License).to receive(:current).and_return(nil)
      end

      it 'returns true when under the limit' do
        expect(described_class.creation_allowed_for_sm?).to be(true)
      end

      it 'returns false when at the limit' do
        stub_const('Authn::ServiceAccounts::LIMIT_FOR_FREE', 2)
        create_list(:user, 2, :service_account)

        expect(described_class.creation_allowed_for_sm?).to be(false)
      end
    end
  end

  describe '.creation_allowed_for_saas?', :saas do
    context 'when root_namespace is nil' do
      it 'returns false' do
        expect(described_class.creation_allowed_for_saas?(nil)).to be(false)
      end
    end

    context 'when namespace has active paid subscription' do
      let_it_be(:group) { create(:group) }

      before do
        create(:gitlab_subscription, :premium, namespace: group)
      end

      it 'returns true' do
        expect(described_class.creation_allowed_for_saas?(group)).to be(true)
      end
    end

    context 'when namespace is on trial' do
      let_it_be(:group) { create(:group) }

      before do
        create(:gitlab_subscription, :active_trial, namespace: group, hosted_plan: create(:ultimate_plan))
      end

      it 'returns true' do
        expect(described_class.creation_allowed_for_saas?(group)).to be(true)
      end
    end

    context 'when namespace has no active paid subscription' do
      let_it_be(:group) { create(:group) }

      it 'returns true when under the free tier limit' do
        expect(described_class.creation_allowed_for_saas?(group)).to be(true)
      end

      it 'returns false when at the free tier limit' do
        stub_const('Authn::ServiceAccounts::LIMIT_FOR_FREE', 2)
        create_list(:user, 2, :service_account, provisioned_by_group_id: group.id)

        expect(described_class.creation_allowed_for_saas?(group)).to be(false)
      end
    end

    context 'when subscription has expired' do
      let_it_be(:group) { create(:group) }

      before do
        create(:gitlab_subscription, :expired, namespace: group)
      end

      it 'returns true when under the free tier limit' do
        expect(described_class.creation_allowed_for_saas?(group)).to be(true)
      end

      it 'returns false when at the free tier limit' do
        stub_const('Authn::ServiceAccounts::LIMIT_FOR_FREE', 2)
        create_list(:user, 2, :service_account, provisioned_by_group_id: group.id)

        expect(described_class.creation_allowed_for_saas?(group)).to be(false)
      end
    end

    context 'when namespace has free plan' do
      let_it_be(:group) { create(:group) }

      before do
        create(:gitlab_subscription, :free, namespace: group)
      end

      it 'returns true when under the free tier limit' do
        expect(described_class.creation_allowed_for_saas?(group)).to be(true)
      end

      it 'returns false when at the free tier limit' do
        stub_const('Authn::ServiceAccounts::LIMIT_FOR_FREE', 2)
        create_list(:user, 2, :service_account, provisioned_by_group_id: group.id)

        expect(described_class.creation_allowed_for_saas?(group)).to be(false)
      end
    end
  end

  describe '.free_tier_limit_available?' do
    context 'when not on SaaS' do
      let_it_be(:group) { create(:group) }

      it 'returns false' do
        expect(described_class.free_tier_limit_available?(group)).to be(false)
      end
    end
  end

  describe '.free_tier?' do
    context 'when license is ultimate' do
      before do
        allow(::License).to receive(:current).and_return(create(:license, plan: License::ULTIMATE_PLAN))
      end

      it { expect(described_class.free_tier?).to be(false) }
    end

    context 'when license is premium' do
      before do
        allow(::License).to receive(:current).and_return(create(:license, plan: License::PREMIUM_PLAN))
      end

      it { expect(described_class.free_tier?).to be(false) }
    end

    context 'when license is starter' do
      before do
        allow(::License).to receive(:current).and_return(create(:license, plan: License::STARTER_PLAN))
      end

      it { expect(described_class.free_tier?).to be(true) }
    end

    context 'when no license is installed' do
      before do
        allow(::License).to receive(:current).and_return(nil)
      end

      it { expect(described_class.free_tier?).to be(true) }
    end
  end

  describe '.free_tier_namespace?', :saas do
    let_it_be(:group) { create(:group) }

    context 'when namespace is nil' do
      it { expect(described_class.free_tier_namespace?(nil)).to be(false) }
    end

    context 'when namespace is on trial' do
      before do
        allow(group.root_ancestor).to receive(:trial_active?).and_return(true)
      end

      it { expect(described_class.free_tier_namespace?(group)).to be(false) }
    end

    context 'when namespace has active paid subscription' do
      before do
        create(:gitlab_subscription, :premium, namespace: group)
      end

      it { expect(described_class.free_tier_namespace?(group)).to be(false) }
    end

    context 'when namespace is on free tier' do
      before do
        create(:gitlab_subscription, :free, namespace: group)
      end

      it { expect(described_class.free_tier_namespace?(group)).to be(true) }
    end

    context 'when namespace has an expired subscription' do
      before do
        create(:gitlab_subscription, :expired, namespace: group)
      end

      it { expect(described_class.free_tier_namespace?(group)).to be(true) }
    end
  end

  describe '.all_service_accounts_in_hierarchy_count' do
    context 'when root_namespace is nil' do
      it 'returns 0' do
        expect(described_class.all_service_accounts_in_hierarchy_count(nil)).to eq(0)
      end
    end

    context 'when root_namespace has service accounts' do
      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:project) { create(:project, group: group) }

      it 'counts group-provisioned service accounts' do
        create_list(:user, 2, :service_account, provisioned_by_group_id: group.id)

        expect(described_class.all_service_accounts_in_hierarchy_count(group)).to eq(2)
      end

      it 'counts subgroup-provisioned service accounts' do
        create(:user, :service_account, provisioned_by_group_id: subgroup.id)

        expect(described_class.all_service_accounts_in_hierarchy_count(group)).to eq(1)
      end

      it 'counts project-provisioned service accounts' do
        create(:user, :service_account, provisioned_by_project_id: project.id)

        expect(described_class.all_service_accounts_in_hierarchy_count(group)).to eq(1)
      end

      it 'counts all service accounts across the hierarchy' do
        create(:user, :service_account, provisioned_by_group_id: group.id)
        create(:user, :service_account, provisioned_by_group_id: subgroup.id)
        create(:user, :service_account, provisioned_by_project_id: project.id)

        expect(described_class.all_service_accounts_in_hierarchy_count(group)).to eq(3)
      end

      it 'includes composite identity service accounts' do
        create(:user, :service_account, provisioned_by_group_id: group.id, composite_identity_enforced: true)
        create(:user, :service_account, provisioned_by_group_id: group.id, composite_identity_enforced: false)

        expect(described_class.all_service_accounts_in_hierarchy_count(group)).to eq(2)
      end
    end
  end
end
