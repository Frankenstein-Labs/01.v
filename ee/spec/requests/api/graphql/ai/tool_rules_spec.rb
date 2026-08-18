# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'aiToolRules query', feature_category: :ai_agents do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:owner) { create(:user, owner_of: group) }

  let(:current_user) { owner }

  let(:query) do
    <<~QUERY
      query aiToolRules($fullPath: ID!, $projectPath: ID) {
        aiToolRules(fullPath: $fullPath, projectPath: $projectPath) {
          nodes {
            id
            name
            webAccess
            localAccess
          }
        }
      }
    QUERY
  end

  let(:variables) { { fullPath: group.full_path } }

  subject(:post_query) do
    post_graphql(query, current_user: current_user, variables: variables)
  end

  it 'returns the tool rules for the namespace' do
    post_query

    nodes = graphql_data_at(:ai_tool_rules, :nodes)
    expect(nodes).to be_present
    expect(nodes.first).to include('id', 'name', 'webAccess', 'localAccess')
  end

  context 'when projectPath belongs to the namespace' do
    let_it_be(:project) { create(:project, namespace: group) }

    let(:variables) { { fullPath: group.full_path, projectPath: project.full_path } }

    it 'returns the effective tool rules', :aggregate_failures do
      post_query

      expect(graphql_errors).to be_nil
      expect(graphql_data_at(:ai_tool_rules, :nodes)).to be_present
    end
  end

  context 'when projectPath is in a different root namespace' do
    let_it_be(:other_group) { create(:group) }
    let_it_be(:other_project) { create(:project, :public, namespace: other_group) }

    let(:variables) { { fullPath: group.full_path, projectPath: other_project.full_path } }

    it 'rejects the query and returns no rule data', :aggregate_failures do
      post_query

      expect(graphql_errors).to include(a_hash_including('message' => 'Project does not belong to the namespace'))
      expect(graphql_data_at(:ai_tool_rules, :nodes)).to be_nil
    end

    # The granular-token boundary comes from `full_path` alone, so a token scoped to the caller's
    # own namespace satisfies the directive and still reached the foreign project before the guard.
    context 'with a granular token bounded to the caller-owned namespace' do
      let(:assignables) do
        [::Authz::PermissionGroups::Assignable.for_permission(:read_ai_tool_rule).min_by(&:name).name]
      end

      let(:pat) do
        create(:granular_pat, user: owner, boundary: ::Authz::Boundary.for(group), permissions: assignables)
      end

      it 'rejects the query despite the token satisfying the boundary', :aggregate_failures do
        post_graphql(query, variables: variables, token: { personal_access_token: pat })

        expect(graphql_errors).to include(a_hash_including('message' => 'Project does not belong to the namespace'))
        expect(graphql_data_at(:ai_tool_rules, :nodes)).to be_nil
      end
    end
  end

  # The field-level `authorize_granular_token` directive enforces the read scope; an unauthorized
  # token nulls the whole `aiToolRules` field (nodes are boundary-less hashes, nothing to redact
  # per-node), so the standard shared example applies, not the "skipped child type" variant.
  it_behaves_like 'authorizing granular token permissions for GraphQL', :read_ai_tool_rule do
    let(:user) { owner }
    let(:boundary_object) { group }
    let(:request) do
      post_graphql(query, variables: { fullPath: group.full_path }, token: { personal_access_token: pat })
    end
  end
end
