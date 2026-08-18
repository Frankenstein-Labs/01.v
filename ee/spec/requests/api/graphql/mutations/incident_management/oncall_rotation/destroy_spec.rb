# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Removing an on-call rotation', feature_category: :incident_management do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, maintainers: user) }
  let_it_be(:schedule) { create(:incident_management_oncall_schedule, project: project) }
  let_it_be(:rotation) { create(:incident_management_oncall_rotation, schedule: schedule) }

  let(:variables) do
    {
      project_path: project.full_path,
      schedule_iid: schedule.iid.to_s,
      id: rotation.to_global_id.to_s
    }
  end

  let(:mutation) do
    graphql_mutation(:oncall_rotation_destroy, variables, 'errors')
  end

  let(:mutation_response) { graphql_mutation_response(:oncall_rotation_destroy) }

  before do
    stub_licensed_features(oncall_schedules: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :delete_oncall_rotation do
    let(:boundary_object) { project }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end

  it 'removes the on-call rotation' do
    post_graphql_mutation(mutation, current_user: user)

    expect(response).to have_gitlab_http_status(:success)
    expect(mutation_response['errors']).to be_empty
    expect { rotation.reload }.to raise_error ActiveRecord::RecordNotFound
  end
end
