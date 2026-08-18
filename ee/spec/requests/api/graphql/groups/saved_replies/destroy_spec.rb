# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Destroy group saved reply', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, maintainer_of: group) }
  let_it_be(:saved_reply) { create(:group_saved_reply, group: group) }

  let(:input) { { id: saved_reply.to_global_id } }

  let(:mutation) { graphql_mutation(:group_saved_reply_destroy, input) }
  let(:mutation_response) { graphql_mutation_response(:group_saved_reply_destroy) }

  context 'when license is invalid' do
    before do
      stub_licensed_features(group_saved_replies: false)
    end

    it 'returns null' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(mutation_response).to be_nil
    end
  end

  context 'when license is valid' do
    before do
      stub_licensed_features(group_saved_replies: true)
    end

    it 'deletes the saved reply' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { ::Groups::SavedReply.count }.by(-1)
    end
  end
end
