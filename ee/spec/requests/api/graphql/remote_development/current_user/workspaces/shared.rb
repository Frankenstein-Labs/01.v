# frozen_string_literal: true

require_relative '../../shared'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.shared_context 'for a Query.currentUser.workspaces query' do
  include GraphqlHelpers

  let_it_be_with_reload(:authorized_user) { workspace.user }
  let_it_be(:unauthorized_user) { create(:user) }

  include_context "with authorized user as developer on workspace's project"

  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('workspaces'.classify, max_depth: 1)}
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      'currentUser',
      query_graphql_field('workspaces', args, fields)
    )
  end

  subject(:actual_workspaces) { graphql_dig_at(graphql_data, :currentUser, :workspaces, :nodes) }
end
