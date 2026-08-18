# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.note(id) for a group-level note', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:user) { create(:user, developer_of: group) }
  let_it_be_with_reload(:epic) { create(:epic, group: group) }
  let_it_be(:note) { create(:note, project: nil, noteable: epic) }
  let(:query) { graphql_query_for('note', { 'id' => global_id_of(note) }, 'id body') }

  before do
    stub_licensed_features(epics: true)
  end

  it_behaves_like 'authorizing granular token permissions for GraphQL', :read_note do
    let(:boundary_object) { group }
    let(:request) { post_graphql(query, token: { personal_access_token: pat }) }
  end
end
