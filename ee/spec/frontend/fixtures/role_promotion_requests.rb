# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Role promotion requests EE (JavaScript fixtures)', feature_category: :consumables_cost_management do
  include JavaScriptFixturesHelpers
  include GraphqlHelpers

  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project_members, freeze: false) do
    create_list(:project_member, 2, project: project, access_level: Gitlab::Access::GUEST)
  end

  let_it_be(:group_members, freeze: false) do
    create_list(:group_member, 2, group: group, access_level: Gitlab::Access::GUEST)
  end

  let_it_be(:member_approvals, freeze: false) do
    [
      create(:gitlab_subscription_member_management_member_approval,
        member_namespace: project_members.first.member_namespace,
        member: project_members.first),
      create(:gitlab_subscription_member_management_member_approval,
        member_namespace: project_members.second.member_namespace,
        member: project_members.second
      ),
      create(:gitlab_subscription_member_management_member_approval,
        member_namespace: group_members.first.member_namespace,
        member: group_members.first),
      create(:gitlab_subscription_member_management_member_approval,
        member_namespace: group_members.second.member_namespace,
        member: group_members.second)
    ]
  end

  let_it_be(:current_user, freeze: false) { create(:user) }
  let_it_be(:ultimate, freeze: false) { create(:license, plan: License::ULTIMATE_PLAN) }

  before do
    allow(License).to receive(:current).and_return(ultimate)
    stub_application_setting(enable_member_promotion_management: true)
  end

  describe GraphQL::Query, type: :request do
    project_query_path = 'members/promotion_requests/graphql/project_pending_member_approvals.query.graphql'
    group_query_path = 'members/promotion_requests/graphql/group_pending_member_approvals.query.graphql'

    it "graphql/members/promotion_requests/project_pending_member_approvals.json" do
      project.add_owner(current_user)
      query = get_graphql_query_as_string(project_query_path, ee: true)

      post_graphql(query, current_user: current_user, variables: { fullPath: project.full_path })

      expect_graphql_errors_to_be_empty
    end

    it "graphql/members/promotion_requests/group_pending_member_approvals.json" do
      group.add_owner(current_user)
      query = get_graphql_query_as_string(group_query_path, ee: true)

      post_graphql(query, current_user: current_user, variables: { fullPath: group.full_path })

      expect_graphql_errors_to_be_empty
    end
  end
end
