# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Reorder work items', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:current_user) { create(:user, reporter_of: group) }
  let_it_be(:item1) { create(:work_item, :epic, namespace: group, relative_position: 10) }
  let_it_be(:item2) { create(:work_item, :epic, namespace: group, relative_position: 20) }

  before do
    stub_licensed_features(epics: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_work_item do
    let(:user) { current_user }
    let(:boundary_object) { group }
    let(:mutation) do
      graphql_mutation(:work_items_reorder,
        { id: item2.to_gid.to_s, move_after_id: item1.to_gid.to_s },
        'errors')
    end

    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
