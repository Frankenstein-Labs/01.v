# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting blocking merge requests', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, source_branch: 'feature-a') }
  let_it_be(:blocking_merge_request) do
    create(:merge_request, source_project: project, source_branch: 'feature-b')
  end

  let(:input) { { blocking_merge_request_references: ["!#{blocking_merge_request.iid}"] } }

  before do
    stub_licensed_features(blocking_merge_requests: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_merge_request do
    let(:user) { current_user }
    let(:boundary_object) { project }
    let(:mutation) do
      graphql_mutation(
        :merge_request_set_blocking_merge_requests,
        { project_path: project.full_path, iid: merge_request.iid.to_s }.merge(input),
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
