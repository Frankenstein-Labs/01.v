# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::MemberManagement::SelfManaged::MaxAccessLevelMemberApprovalsFinder, feature_category: :seat_cost_management do
  let_it_be(:admin_user) { create(:user) }
  let_it_be(:project_member_pending_dev) do
    create(:gitlab_subscription_member_management_member_approval, :for_project_member)
  end

  let_it_be(:project_member_pending_maintainer) do
    create(:gitlab_subscription_member_management_member_approval, user: project_member_pending_dev.user,
      new_access_level: Gitlab::Access::MAINTAINER)
  end

  let_it_be(:group_member_pending_dev) do
    create(:gitlab_subscription_member_management_member_approval, :for_group_member)
  end

  let_it_be(:group_member_pending_owner) do
    create(:gitlab_subscription_member_management_member_approval,
      :for_group_member,
      user: group_member_pending_dev.user,
      new_access_level: Gitlab::Access::OWNER
    )
  end

  let_it_be(:denied_approval_dev) do
    create(:gitlab_subscription_member_management_member_approval, :for_group_member, status: :denied)
  end

  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:feature_setting) { true }
  let_it_be(:user) { admin_user }

  subject(:finder) { described_class.new(user) }

  describe '#execute' do
    before do
      allow(admin_user).to receive(:can_admin_all_resources?).and_return(true)
      stub_application_setting(enable_member_promotion_management: feature_setting)
      allow(License).to receive(:current).and_return(license)
    end

    shared_examples 'returns empty' do
      it 'returns empty' do
        expect(finder.execute).to be_empty
      end
    end

    context 'when user does not have admin access' do
      let(:user) { create(:user) }

      it_behaves_like 'returns empty'
    end

    context 'when user has admin access' do
      it 'returns records corresponding to pending users with max new_access_level' do
        expect(finder.execute).to contain_exactly(project_member_pending_maintainer, group_member_pending_owner)
      end

      context 'when member promotion management is disabled in settings' do
        let(:feature_setting) { false }

        it_behaves_like 'returns empty'
      end

      context 'when subscription plan is not Ultimate' do
        let(:license) { create(:license, plan: License::STARTER_PLAN) }

        it_behaves_like 'returns empty'
      end

      context 'when instance is saas', :saas do
        it_behaves_like 'returns empty'
      end
    end
  end
end
