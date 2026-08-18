# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Delete an AI conversation thread', feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:other_user) { create(:user) }
  let_it_be(:thread) { create(:ai_conversation_thread, user: user) }
  let_it_be(:other_thread) { create(:ai_conversation_thread, user: other_user) }

  let(:current_user) { user }
  let(:mutation) { graphql_mutation(:deleteConversationThread, { 'threadId' => thread.to_global_id.to_s }) }
  let(:mutation_response) { graphql_mutation_response(:delete_conversation_thread) }

  context 'when the user owns the thread' do
    it 'deletes the thread' do
      expect do
        post_graphql_mutation(mutation, current_user: current_user)
      end.to change { Ai::Conversation::Thread.count }.by(-1)

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end
  end

  context 'when the user does not own the thread' do
    let(:thread) { other_thread }

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when the thread does not exist' do
    before do
      thread.destroy!
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end
end
