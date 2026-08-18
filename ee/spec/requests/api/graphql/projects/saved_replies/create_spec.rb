# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create project saved reply', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, maintainer_of: project) }

  let(:input) { { project_id: project.to_global_id, name: 'Test name', content: 'Test content' } }

  let(:mutation) { graphql_mutation(:project_saved_reply_create, input) }
  let(:mutation_response) { graphql_mutation_response(:project_saved_reply_create) }

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

    it 'creates a saved reply' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(mutation_response['savedReply']).to include(
          'name' => 'Test name',
          'content' => 'Test content'
        )
      end.to change { ::Projects::SavedReply.count }.by(1)
    end

    context 'when saved reply exists' do
      let_it_be(:saved_reply) { create(:project_saved_reply, project: project, name: 'Test name') }

      it_behaves_like 'a mutation that returns errors in the response', errors: ["Name has already been taken"]
    end
  end
end
