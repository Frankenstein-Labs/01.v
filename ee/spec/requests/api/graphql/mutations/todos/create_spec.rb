# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a todo for a group-scoped target', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:target) { create(:epic, group: group) }

  let(:input) do
    {
      'targetId' => target.to_global_id.to_s
    }
  end

  let(:mutation) { graphql_mutation(:todoCreate, input) }
  let(:mutation_response) { graphql_mutation_response(:todoCreate) }

  before do
    stub_licensed_features(epics: true)
  end

  context 'when user has permission to create the todo through group membership' do
    before_all do
      group.add_guest(current_user)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :create_todo do
      let(:user) { current_user }
      let(:boundary_object) { group }
      let(:mutation) { graphql_mutation(:todoCreate, input, 'errors') }
      let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
    end

    it 'creates the todo' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['todo']['state']).to eq('pending')
    end
  end
end
