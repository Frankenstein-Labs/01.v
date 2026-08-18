# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group saved reply', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:saved_reply) { create(:group_saved_reply, group: group) }
  let(:current_user) { user }

  let(:query) do
    <<~QUERY
      query groupSavedReplies($groupPath: ID!, $savedReplyId: GroupsSavedReplyID!) {
        group(fullPath: $groupPath) {
          id
          savedReply(id: $savedReplyId) {
            id
            name
            content
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(
      query,
      current_user: current_user,
      variables: {
        groupPath: group.full_path,
        saved_reply_id: saved_reply.to_global_id
      }
    )
  end

  context 'when license is invalid' do
    before do
      stub_licensed_features(group_saved_replies: false)
    end

    it 'returns null' do
      post_query

      expect(saved_reply_graphl_response).to be_nil
    end
  end

  context 'when license is valid' do
    before do
      stub_licensed_features(group_saved_replies: true)
    end

    it 'returns group saved reply' do
      post_query

      expect(saved_reply_graphl_response).to match(a_graphql_entity_for(saved_reply, :name, :content))
    end
  end

  context 'when current user is not a member of the group' do
    let_it_be(:non_member) { create(:user) }
    let(:current_user) { non_member }

    before do
      stub_licensed_features(group_saved_replies: true)
    end

    it 'returns group saved reply' do
      post_query

      expect(saved_reply_graphl_response).to be_nil
    end
  end

  def saved_reply_graphl_response
    graphql_dig_at(graphql_data, :group, :saved_reply)
  end
end
