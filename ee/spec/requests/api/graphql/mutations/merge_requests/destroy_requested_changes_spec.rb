# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy merge request change request', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) do
    create(:merge_request, target_project: project, source_project: project)
  end

  let_it_be(:requested_change) do
    create(:merge_request_requested_changes, merge_request: merge_request, project: project,
      user: current_user)
  end

  let(:mutation) do
    graphql_mutation(:merge_request_destroy_requested_changes,
      { project_path: project.full_path, iid: merge_request.iid.to_s })
  end

  def mutation_response
    graphql_mutation_response(:merge_request_destroy_requested_changes)
  end

  before_all do
    project.add_maintainer(current_user)
  end

  context 'when project has incorrect license' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: false)
    end

    it 'returns error' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['errors']).to contain_exactly('Invalid license')
    end
  end

  context 'when project has correct license and user has update permissions' do
    before do
      stub_licensed_features(requested_changes_block_merge_request: true)
    end

    it 'returns success' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['errors']).to be_empty
    end

    it 'destroys change request' do
      expect { post_graphql_mutation(mutation, current_user: current_user) }.to change {
        merge_request.requested_changes.count
      }.from(1).to(0)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :update_merge_request do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:mutation) do
        graphql_mutation(
          :merge_request_destroy_requested_changes,
          { project_path: project.full_path, iid: merge_request.iid.to_s },
          'errors'
        )
      end

      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end
  end
end
