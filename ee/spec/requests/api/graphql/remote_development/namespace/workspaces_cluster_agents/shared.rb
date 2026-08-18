# frozen_string_literal: true

require_relative "../../shared"

#-------------------------------------------------
# SHARED CONTEXTS - INDIVIDUAL ARGUMENTS SCENARIOS
#-------------------------------------------------

# noinspection RubyArgCount
RSpec.shared_context "with filter argument" do
  let_it_be(:namespace) { create(:group, name: "group-namespace") }
  let_it_be(:project) do
    create(:project, :in_group, path: "project", namespace: namespace)
  end

  let_it_be(:authorized_user) do
    create(:user).tap do |user|
      # create the minimum privileged user that should have the project and namespace
      # permissions to access the agent.
      project.add_member(user, authorized_user_project_access_level) if authorized_user_project_access_level
      namespace.add_member(user, authorized_user_namespace_access_level) if authorized_user_namespace_access_level
    end
  end

  let_it_be(:unauthorized_user) do
    # create the maximum privileged user that should NOT have the project and namespace
    # permissions to access the agent.
    create(:user).tap do |user|
      project.add_member(user, unauthorized_user_project_access_level) if unauthorized_user_project_access_level
      namespace.add_member(user, unauthorized_user_namespace_access_level) if unauthorized_user_namespace_access_level
    end
  end

  let_it_be(:project_namespace) { project.project_namespace }

  let_it_be(:available_agent) do
    create(:ee_cluster_agent, :with_existing_workspaces_agent_config, project: project,
      created_by_user: authorized_user, name: "available-agent").tap do |agent|
      create(
        :namespace_cluster_agent_mapping,
        user: authorized_user,
        agent: agent,
        namespace: namespace
      )
    end
  end

  let_it_be(:directly_mapped_agent) do
    create(:cluster_agent, project: project, created_by_user: authorized_user,
      name: "directly-mapped-agent").tap do |agent|
      create(
        :namespace_cluster_agent_mapping,
        user: authorized_user,
        agent: agent,
        namespace: namespace
      )
    end
  end

  let_it_be(:unmapped_agent) do
    create(:cluster_agent, project: project, created_by_user: authorized_user, name: "unmapped-agent")
  end

  let_it_be(:unauthorized_agent) { create(:cluster_agent, :in_group) }
end

RSpec.shared_context "for a Query.namespace.workspaces_cluster_agents query" do
  include GraphqlHelpers

  let(:args) { { full_path: namespace.full_path } }

  let(:attributes) { { filter: filter } }

  let(:fields) do
    query_graphql_field(
      :workspaces_cluster_agents,
      attributes,
      [
        query_graphql_field(
          :nodes,
          all_graphql_fields_for("cluster_agents".classify, max_depth: 1)
        )
      ]
    )
  end

  let(:query) { graphql_query_for(:namespace, args, fields) }

  subject(:actual_agents) { graphql_dig_at(graphql_data, :namespace, :workspacesClusterAgents, :nodes) }
end

#------------------------------------------------
# SHARED EXAMPLES - MAIN ENTRY POINTS FOR TESTING
#------------------------------------------------

RSpec.shared_examples "multiple agents in namespace query" do
  include_context "in licensed environment"

  let(:agent_names) { actual_agents.pluck("name") }
  let(:expected_agent_names) { expected_agents.pluck("name").sort }

  context "when user is authorized" do
    include_context "with authorized user as current user"

    it_behaves_like "query is a working graphql query"

    context "when the user requests an agent that they are authorized for" do
      before do
        post_graphql(query, current_user: current_user)
      end

      it "includes only the expected agent", :unlimited_max_formatted_output_length do
        expect(agent_names.sort).to eq(expected_agent_names)
      end
    end

    context "when the user requests an agent that they are not authorized for" do
      before do
        post_graphql(query, current_user: current_user)
      end

      it "does not return the unauthorized agent" do
        expect(agent_names).not_to include(unauthorized_agent.name)
      end

      it "still returns the authorized agent" do
        expect(agent_names).to include(agent.name)
      end
    end

    context "when the provided namespace is not a group namespace" do
      let(:namespace) { project_namespace }

      it_behaves_like "query returns blank"
      it_behaves_like "query includes graphql error",
        "does not exist or you don't have permission to perform this action"
    end
  end

  context "when user is not authorized" do
    include_context "with unauthorized user as current user"

    it_behaves_like "query is a working graphql query"
    it_behaves_like "query returns blank"
  end

  it_behaves_like "query in unlicensed environment"
end
