# frozen_string_literal: true

require_relative "../../shared"

#-------------------------------------------------
# SHARED CONTEXTS - INDIVIDUAL ARGUMENTS SCENARIOS
#-------------------------------------------------

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.shared_context "with agents and users setup in an organization" do
  let_it_be(:organization) { create(:common_organization) }

  let_it_be(:authorized_user) do
    create(:user, owner_of: organization)
  end

  let_it_be(:unauthorized_user) { create(:user, organization: create(:organization)) }

  let_it_be(:mapped_agent) do
    project = create(:project, organization: organization, namespace: create(:group))
    create(:ee_cluster_agent, project: project, name: "agent-in-org-available").tap do |agent|
      create(:workspaces_agent_config, agent: agent)
      create(:organization_cluster_agent_mapping, user: authorized_user, agent: agent, organization: organization)
    end
  end

  let_it_be(:unmapped_agent) do
    project = create(:project, organization: organization)
    create(:ee_cluster_agent, project: project, name: "agent-in-org-unmapped").tap do |agent|
      create(:workspaces_agent_config, agent: agent)
    end
  end

  let_it_be(:agent_in_another_org) do
    project = create(:project, organization: create(:organization))
    create(:ee_cluster_agent, project: project, name: "agent-in-another-org").tap do |agent|
      create(:workspaces_agent_config, agent: agent)
    end
  end
end

RSpec.shared_context "for a Query.organization.workspaces_cluster_agents query" do
  include GraphqlHelpers

  let(:args) { { id: organization.to_gid } }

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

  let(:query) { graphql_query_for(:organization, args, fields) }

  subject(:actual_agents) { graphql_dig_at(graphql_data, :organization, :workspacesClusterAgents, :nodes) }
end

#------------------------------------------------
# SHARED EXAMPLES - MAIN ENTRY POINTS FOR TESTING
#------------------------------------------------

RSpec.shared_examples "multiple agents in organization query" do
  include_context "in licensed environment"

  let(:agent_names) { actual_agents.pluck("name") }
  let(:expected_agent_names) { expected_agents.pluck("name").sort }

  context "when user is fully authorized" do
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

    context "when the user requests agents in their current organization" do
      before do
        post_graphql(query, current_user: current_user)
      end

      it "does not return agents in another organizations" do
        expect(agent_names).not_to include(agent_in_another_org.name)
      end
    end
  end

  # noinspection RubyArgCount -- Rubymine detecting wrong types, thinks some #create are from Minitest, not FactoryBot
  context "when the user is authorized only on mapped agents" do
    let_it_be(:current_user) do
      create(:user, organization: organization)
    end

    it_behaves_like "query is a working graphql query"

    context "when the user requests agents" do
      before do
        post_graphql(query, current_user: current_user)
      end

      it "does not include unmapped and unavailable agents", :unlimited_max_formatted_output_length do
        expect(agent_names.sort).not_to include(unmapped_agent.name)
      end
    end
  end

  context "when user is not authorized" do
    include_context "with unauthorized user as current user"

    it_behaves_like "query is a working graphql query"
    it_behaves_like "query returns blank"
  end

  it_behaves_like "query in unlicensed environment"
end
