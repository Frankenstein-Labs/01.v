# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::GitlabSubscriptions::MemberManagement::SelfManaged::UsersQueuedForRolePromotionResolver, feature_category: :seat_cost_management do
  include GraphqlHelpers

  let_it_be(:admin_user) { create(:user) }
  let_it_be(:normal_user) { create(:user) }
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
      :for_group_member, user: group_member_pending_dev.user,
      new_access_level: Gitlab::Access::OWNER
    )
  end

  let_it_be(:denied_approval_dev) do
    create(:gitlab_subscription_member_management_member_approval, :for_group_member, status: :denied)
  end

  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:feature_setting) { true }
  let_it_be(:current_user) { admin_user }

  describe '#resolve' do
    subject(:result) { resolve(described_class, ctx: { current_user: current_user }) }

    before do
      stub_application_setting(enable_member_promotion_management: feature_setting)
      allow(License).to receive(:current).and_return(license)

      allow(admin_user).to receive(:can_admin_all_resources?).and_return(true)
    end

    shared_examples 'not available' do
      it 'raises a resource not available error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          result
        end
      end
    end

    context 'when the user is not an admin' do
      let(:current_user) { normal_user }

      it_behaves_like 'not available'
    end

    context 'when the user is an admin' do
      it 'returns pending member_approvals corresponding to max new_access_level' do
        expect(result).to contain_exactly(project_member_pending_maintainer, group_member_pending_owner)
      end

      it 'does not return member_approvals with different status' do
        expect(result).not_to include(denied_approval_dev)
      end

      context 'when member promotion management is disabled in settings' do
        let(:feature_setting) { false }

        it_behaves_like 'not available'
      end

      context 'when subscription plan is not Ultimate' do
        let(:license) { create(:license, plan: License::STARTER_PLAN) }

        it_behaves_like 'not available'
      end

      context 'when instance is saas', :saas do
        it_behaves_like 'not available'
      end
    end
  end
end
