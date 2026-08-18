# frozen_string_literal: true

require_relative "../workspaces_cluster_agents/shared"

RSpec.shared_context "for a Query.namespace.remote_development_cluster_agents query" do
  include_context "for a Query.namespace.workspaces_cluster_agents query"

  let(:fields) do
    query_graphql_field(
      :remote_development_cluster_agents,
      attributes,
      [
        query_graphql_field(
          :nodes,
          all_graphql_fields_for("cluster_agents".classify, max_depth: 1)
        )
      ]
    )
  end

  subject(:actual_agents) { graphql_dig_at(graphql_data, :namespace, :remoteDevelopmentClusterAgents, :nodes) }
end
