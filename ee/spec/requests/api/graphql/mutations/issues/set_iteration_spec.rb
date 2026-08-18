# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Setting the iteration of an issue', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence) }
  let_it_be_with_reload(:issue) { create(:issue, project: project) }

  let(:input) { { iteration_id: global_id_of(iteration) } }

  let(:mutation) do
    graphql_mutation(
      :issue_set_iteration,
      { project_path: project.full_path, iid: issue.iid.to_s }.merge(input),
      <<~GRAPHQL
        clientMutationId
        errors
        issue {
          iid
          iteration {
            id
          }
        }
      GRAPHQL
    )
  end

  def mutation_response
    graphql_mutation_response(:issue_set_iteration)
  end

  before_all do
    project.add_developer(current_user)
  end

  before do
    stub_licensed_features(iterations: true)
  end

  it 'returns an error if the user is not allowed to update the issue' do
    error = "The resource that you are attempting to access does not exist or you " \
      "don't have permission to perform this action"

    post_graphql_mutation(mutation, current_user: create(:user))

    expect(graphql_errors).to include(a_hash_including('message' => error))
  end

  it 'sets the iteration on the issue' do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['errors']).to be_empty
    expect(mutation_response['issue']['iteration']['id']).to eq(global_id_of(iteration).to_s)
    expect(issue.reload.iteration).to eq(iteration)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_issue do
    let(:user) { current_user }
    let(:boundary_object) { project }
    let(:mutation) do
      graphql_mutation(
        :issue_set_iteration,
        { project_path: project.full_path, iid: issue.iid.to_s, iteration_id: global_id_of(iteration) },
        'errors'
      )
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
