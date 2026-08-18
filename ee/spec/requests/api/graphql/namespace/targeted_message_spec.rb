# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting targeted message data for a namespace', feature_category: :acquisition do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:group) { create(:group, owners: [user], developers: [developer]) }
  let_it_be(:targeted_message) { create(:targeted_message, roles: [Gitlab::Access::OWNER]) }
  let_it_be(:targeted_message_namespace) do
    create(:targeted_message_namespace, namespace: group, targeted_message: targeted_message)
  end

  let(:query) do
    graphql_query_for(
      :namespace,
      { full_path: group.full_path },
      query_graphql_field(:targeted_messages, {}, 'id targetType')
    )
  end

  context 'when user is the owner of the namespace' do
    it 'returns the targeted messages' do
      post_graphql(query, current_user: user)

      targeted_messages = graphql_data_at(:namespace, :targeted_messages)
      expect(targeted_messages).to be_an(Array)
      expect(targeted_messages.first['id']).to eq(targeted_message.to_global_id.to_s)
      expect(targeted_messages.first['targetType']).to eq('banner_page_level')
    end
  end

  context 'when user is not the owner of the namespace' do
    it 'returns an empty array' do
      post_graphql(query, current_user: developer)

      expect(graphql_data_at(:namespace, :targeted_messages)).to eq([])
    end
  end
end
