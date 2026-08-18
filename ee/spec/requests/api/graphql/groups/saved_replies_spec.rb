# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group saved replies', feature_category: :code_review_workflow do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group, maintainers: user) }
  let_it_be(:saved_reply) { create(:group_saved_reply, group: group) }
  let(:include_ancestor_groups) { false }
  let(:group_path) { group.full_path }

  let(:query) do
    <<~QUERY
      query groupSavedReplies($groupPath: ID! $includeAncestorGroups: Boolean) {
        group(fullPath: $groupPath) {
          id
          savedReplies(includeAncestorGroups: $includeAncestorGroups) {
            nodes {
              id
              name
              content
            }
          }
        }
      }
    QUERY
  end

  subject(:post_query) do
    post_graphql(
      query,
      current_user: user,
      variables: {
        groupPath: group_path,
        includeAncestorGroups: include_ancestor_groups
      }
    )
  end

  context 'when license is invalid' do
    before do
      stub_licensed_features(group_saved_replies: false)
    end

    it 'returns nil' do
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

      expect(saved_reply_graphl_response).to contain_exactly(a_graphql_entity_for(saved_reply, :name, :content))
    end

    context 'when group path is a sub-group' do
      let_it_be(:subgroup) { create(:group, parent: group) }
      let(:group_path) { subgroup.full_path }
      let(:include_ancestor_groups) { true }

      it 'includes saved replies from ancestor groups' do
        post_query

        expect(saved_reply_graphl_response).to contain_exactly(a_graphql_entity_for(saved_reply, :name, :content))
      end
    end
  end

  def saved_reply_graphl_response
    graphql_dig_at(graphql_data, :group, :saved_replies, :nodes)
  end
end
