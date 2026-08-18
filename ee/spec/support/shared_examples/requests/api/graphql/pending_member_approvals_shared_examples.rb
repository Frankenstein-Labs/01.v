# frozen_string_literal: true

RSpec.shared_examples 'graphql pending members approval list spec' do
  include GraphqlHelpers

  let_it_be(:member_approvals, freeze: false) do
    [
      create(:gitlab_subscription_member_management_member_approval, member_namespace: members.first.member_namespace,
        member: members.first),
      create(:gitlab_subscription_member_management_member_approval, member_namespace: members.second.member_namespace,
        member: members.second)
    ]
  end

  let_it_be(:current_user, freeze: false) { create(:user) }
  let_it_be(:ultimate, freeze: false) { create(:license, plan: License::ULTIMATE_PLAN) }
  let(:query) do
    graphql_query_for(
      parent_key,
      { 'fullPath' => parent.full_path },
      "pendingMemberApprovals {
        count
        edges {
          node {
            user { username }
            member {
              __typename
              accessLevel { integerValue }
            }
            newAccessLevel { integerValue }
            oldAccessLevel { integerValue }
            status
            memberRoleId
          }
        }
      }"
    )
  end

  subject(:result) { GitlabSchema.execute(query, context: { current_user: current_user }).as_json }

  before do
    allow(License).to receive(:current).and_return(ultimate)
    stub_application_setting(enable_member_promotion_management: true)
  end

  context 'when user has permissions to query' do
    before do
      parent.add_owner(current_user)
    end

    it 'returns valid count' do
      expect(result.dig('data', parent_key, 'pendingMemberApprovals', 'count')).to eq(2)
    end

    it 'returns all member_approvals', :aggregate_failures do
      returned_pending_approvals = result.dig('data', parent_key, 'pendingMemberApprovals', 'edges')

      expect(returned_pending_approvals).to be_present
      expect(returned_pending_approvals.count).to eq(2)

      usernames = returned_pending_approvals.map { |edge| edge.dig("node", "user", "username") }
      expect(usernames).to match_array(member_approvals.map { |approval| approval.user.username })

      approval = returned_pending_approvals.first['node']
      expect(approval.keys).to match_array(%w[user member newAccessLevel oldAccessLevel status memberRoleId])
      expect(approval["member"]["__typename"]).to eq("#{parent_key.capitalize}Member")
      expect(approval["member"]["accessLevel"]["integerValue"]).to eq(Gitlab::Access::GUEST)
      expect(approval["newAccessLevel"]["integerValue"]).to eq(Gitlab::Access::DEVELOPER)
      expect(approval["oldAccessLevel"]["integerValue"]).to eq(Gitlab::Access::GUEST)
      expect(approval["status"]).to eq("pending")
      expect(approval["member_role_id"]).to be_nil
    end
  end

  context 'when user does not have permission to query' do
    before do
      parent.add_developer(current_user)
    end

    it 'returns valid count' do
      expect(result.dig('data', parent_key, 'pendingMemberApprovals')).to be_nil
    end
  end
end
