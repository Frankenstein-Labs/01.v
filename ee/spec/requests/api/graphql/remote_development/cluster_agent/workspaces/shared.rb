# frozen_string_literal: true

require_relative '../../shared'

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.shared_context 'for a Query.project.clusterAgent.workspaces query' do
  include GraphqlHelpers

  let_it_be(:cluster_admin_user, freeze: false) { create(:user) }
  let_it_be(:authorized_user, freeze: false) { cluster_admin_user }

  # NOTE: We use the workspace owner as the unauthorized user, because they should not have any access to the workspace
  #       via the Query.project.clusterAgent.workspaces query, even if they otherwise have full access to the workspace.
  let_it_be_with_reload(:unauthorized_user) { workspace.user }

  let_it_be_with_reload(:agent) { workspace.agent }
  let_it_be_with_reload(:agent_project) { agent.project }

  let(:fields) do
    <<~QUERY
      nodes {
        #{all_graphql_fields_for('workspaces'.classify, max_depth: 1)}
      }
    QUERY
  end

  let(:query) do
    graphql_query_for(
      :project,
      { full_path: agent_project.full_path },
      query_graphql_field(
        :cluster_agent,
        { name: agent.name },
        query_graphql_field('workspaces', args, fields)
      )
    )
  end

  before do
    agent_project.add_maintainer(cluster_admin_user)
    agent.update!(created_by_user: cluster_admin_user)
    workspace.reload # Ensure loaded workspace fixture's agent reflects updated created_by_user
  end

  subject(:actual_workspaces) { graphql_dig_at(graphql_data, :project, :clusterAgent, :workspaces, :nodes) }
end
