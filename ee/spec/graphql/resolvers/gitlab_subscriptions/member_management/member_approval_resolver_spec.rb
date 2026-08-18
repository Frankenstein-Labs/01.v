# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::GitlabSubscriptions::MemberManagement::MemberApprovalResolver, feature_category: :seat_cost_management do
  include GraphqlHelpers

  let(:feature_setting) { true }
  let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let(:parent) { group }

  subject(:result) { resolve(described_class, obj: parent, ctx: { current_user: current_user }) }

  describe '#resolve' do
    before do
      stub_application_setting(enable_member_promotion_management: feature_setting)
      allow(License).to receive(:current).and_return(license)
    end

    shared_examples 'queries member approvals' do
      let_it_be(:member_approvals) do
        [
          create(:gitlab_subscription_member_management_member_approval,
            member_namespace: members.first.member_namespace, member: members.first),
          create(:gitlab_subscription_member_management_member_approval,
            member_namespace: members.second.member_namespace, member: members.second)
        ]
      end

      context 'when user has permission to query' do
        before do
          parent.add_owner(current_user)
        end

        it 'returns the member_approvals' do
          expect(result).to match_array(member_approvals)
        end
      end

      context 'when user does not have permission' do
        it 'returns nil' do
          expect(result).to be_nil
        end
      end
    end

    context 'when promotion management is applicable' do
      context 'when called from group' do
        let(:parent) { group }
        let_it_be(:members) do
          create_list(:group_member, 2, group: group, access_level: Gitlab::Access::GUEST)
        end

        it_behaves_like 'queries member approvals'
      end

      context 'when called from project' do
        let(:parent) { project }
        let_it_be(:members) do
          create_list(:project_member, 2, project: project, access_level: Gitlab::Access::GUEST)
        end

        it_behaves_like 'queries member approvals'
      end

      context 'when called on a different object' do
        let(:parent) { create(:user) }

        it 'raises ResourceNotAvailable error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
            result
          end
        end
      end
    end
  end
end
