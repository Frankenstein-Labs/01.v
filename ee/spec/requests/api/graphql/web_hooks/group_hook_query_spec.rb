# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying for a group hook', feature_category: :webhooks do
  include GraphqlHelpers

  let_it_be(:group_hook) { create(:group_hook) }
  let_it_be(:user) { create(:user) }
  let_it_be(:current_user) { user }

  def query
    graphql_query_for(
      'group',
      { 'fullPath' => group_hook.group.full_path },
      <<~GRAPHQL
        webhook(id: "#{GitlabSchema.id_from_object(group_hook)}") {
          id
        }
      GRAPHQL
    )
  end

  before do
    post_graphql(query, current_user: current_user)
  end

  context 'when the user is authorized' do
    before_all do
      group_hook.group.add_owner(current_user)
    end

    it 'returns the group hook' do
      response_id = graphql_data_at('group', 'webhook', 'id')

      expect(response_id).to eq(global_id_of(group_hook).to_s)
    end
  end

  context 'when the user is not authorized' do
    before_all do
      group_hook.group.add_maintainer(current_user)
    end

    it 'does not return the group hook' do
      response_id = graphql_data_at('group', 'webhook')

      expect(response_id).to be_nil
    end
  end
end
