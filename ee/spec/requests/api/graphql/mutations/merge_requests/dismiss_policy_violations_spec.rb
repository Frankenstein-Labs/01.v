# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dismissing policy violations linked to a merge request', feature_category: :security_policy_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:policy) { create(:security_policy, :enforcement_type_warn) }
  let_it_be(:approval_policy_rule) { create(:approval_policy_rule, security_policy: policy) }

  let(:input) do
    {
      security_policy_ids: [policy.id],
      dismissal_types: ['EMERGENCY_HOT_FIX'],
      comment: 'Test dismissal'
    }
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_merge_request do
    let(:user) { current_user }
    let(:boundary_object) { project }
    let(:mutation) do
      graphql_mutation(
        :dismiss_policy_violations,
        { project_path: project.full_path, iid: merge_request.iid.to_s }.merge(input),
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
