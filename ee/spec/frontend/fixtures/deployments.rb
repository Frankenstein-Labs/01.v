# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deployments (JavaScript fixtures)', feature_category: :deployment_management do
  include ApiHelpers
  include JavaScriptFixturesHelpers

  let_it_be(:group, freeze: false) { create(:group, path: 'deployment-group') }
  let_it_be(:user, freeze: false) do
    create(:user, username: 'my-user', email: 'user@example.gitlab.com', maintainer_of: group)
  end

  let_it_be(:project, freeze: false) { create(:project, :repository, group: group, path: 'releases-project') }
  let_it_be(:private_group, freeze: false) { create(:group, :private, path: 'private-group') }

  let_it_be(:environment, freeze: false) do
    create(:environment, project: project, external_url: 'http://example.com')
  end

  let_it_be(:protected_environment, freeze: false) do
    create(:protected_environment, name: environment.name, project: project)
  end

  let_it_be(:approval_group, freeze: false) do
    create(:protected_environment_approval_rule, group: group, protected_environment: protected_environment)
  end

  let_it_be(:approval_private_group, freeze: false) do
    create(:protected_environment_approval_rule, group: private_group, protected_environment: protected_environment)
  end

  let_it_be(:approval_user, freeze: false) do
    create(:protected_environment_approval_rule, user: user, protected_environment: protected_environment)
  end

  let_it_be(:approval_maintainer, freeze: false) do
    create(:protected_environment_approval_rule, :maintainer_access, protected_environment: protected_environment)
  end

  let_it_be(:approval_developer, freeze: false) do
    create(:protected_environment_approval_rule, :developer_access, protected_environment: protected_environment)
  end

  let_it_be(:pipeline, freeze: false) { create(:ci_pipeline, project: project) }
  let_it_be(:build, freeze: false) { create(:ci_build, :success, pipeline: pipeline) }

  let_it_be(:deployment, freeze: false) do
    create(:deployment, :success, environment: environment, deployable: build)
  end

  let_it_be(:approval, freeze: false) do
    create(:deployment_approval, user: user, deployment: deployment, approval_rule: approval_group,
      comment: 'Looks good')
  end

  let_it_be(:approved_no_comment_user, freeze: false) do
    create(:user, username: 'approved-no-comment', email: 'approved-no-comment@example.gitlab.com')
  end

  let_it_be(:approval_without_comment, freeze: false) do
    create(:deployment_approval, user: approved_no_comment_user, deployment: deployment,
      approval_rule: approval_developer, comment: '')
  end

  let_it_be(:rejecting_user, freeze: false) do
    create(:user, username: 'rejected-with-comment', email: 'rejecting@example.gitlab.com')
  end

  let_it_be(:rejection, freeze: false) do
    create(:deployment_approval, :rejected, user: rejecting_user, deployment: deployment, approval_rule: approval_user,
      comment: 'Needs work')
  end

  let_it_be(:rejected_no_comment_user, freeze: false) do
    create(:user, username: 'rejected-no-comment', email: 'rejected-no-comment@example.gitlab.com')
  end

  let_it_be(:rejection_without_comment, freeze: false) do
    create(:deployment_approval, :rejected, user: rejected_no_comment_user, deployment: deployment,
      approval_rule: approval_maintainer, comment: '')
  end

  describe GraphQL::Query, type: :request do
    include GraphqlHelpers

    one_deployment_query_path = 'environments/graphql/queries/deployment.query.graphql'

    it "graphql/#{one_deployment_query_path}.json" do
      query = get_graphql_query_as_string(one_deployment_query_path, ee: true)

      post_graphql(query, current_user: user, variables: { fullPath: project.full_path, iid: deployment.iid })

      expect_graphql_errors_to_be_empty
      expect(graphql_data_at(:project, :deployment)).to be_present
    end

    deployment_details_query_path = 'deployments/graphql/queries/deployment.query.graphql'

    it "ee/graphql/#{deployment_details_query_path}.json" do
      query = get_graphql_query_as_string(deployment_details_query_path)

      post_graphql(query, current_user: user, variables: { fullPath: project.full_path, iid: deployment.iid })

      expect_graphql_errors_to_be_empty
      expect(graphql_data_at(:project, :deployment)).to be_present
    end
  end
end
