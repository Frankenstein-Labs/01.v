# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update project saved reply', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }
  let_it_be(:saved_reply) { create(:project_saved_reply, project: project, name: 'Old name', content: 'Old content') }

  let(:input) { { id: saved_reply.to_global_id, name: 'New name', content: 'New content' } }

  let(:mutation) { graphql_mutation(:project_saved_reply_update, input) }
  let(:mutation_response) { graphql_mutation_response(:project_saved_reply_update) }

  context 'when license is invalid' do
    before do
      stub_licensed_features(project_saved_replies: false)
    end

    it 'returns null' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response).to be_nil
    end
  end

  context 'when license is valid' do
    before do
      stub_licensed_features(project_saved_replies: true)
    end

    it 'updates the saved reply' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response['savedReply']).to include(
        'name' => 'New name',
        'content' => 'New content'
      )
    end
  end
end
