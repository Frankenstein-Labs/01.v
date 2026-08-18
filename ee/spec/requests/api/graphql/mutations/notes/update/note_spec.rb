# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Updating a group-level note', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:epic) { create(:epic, group: group) }
  let_it_be_with_reload(:note) { create(:note, project: nil, noteable: epic, author: user) }
  let(:mutation) do
    graphql_mutation(:update_note, { id: global_id_of(note).to_s, body: 'updated' }, 'errors')
  end

  before do
    stub_licensed_features(epics: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :update_note do
    let(:boundary_object) { group }
    let(:request) { post_graphql_mutation(mutation, token: { personal_access_token: pat }) }
  end
end
