# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Querying session artifacts for a project', feature_category: :duo_agent_platform do
  include GraphqlHelpers

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:sibling_project) { create(:project, group: group) }
  let_it_be(:owner) { create(:user) }
  let_it_be(:non_member) { create(:user) }

  # The duoWorkflowSessionArtifacts field requires :read_agent_artifacts, a
  # custom ability granted via member roles (requires the custom_roles license).
  let_it_be(:owner_role) { create(:member_role, :guest, :read_agent_artifacts, namespace: group) }
  let_it_be(:owner_membership) do
    create(:project_member, :guest, member_role: owner_role, user: owner, project: project)
  end

  let_it_be(:workflow1) { create(:duo_workflows_workflow, project: project, user: owner) }
  let_it_be(:workflow2) { create(:duo_workflows_workflow, project: project, user: owner) }
  let_it_be(:sibling_workflow) { create(:duo_workflows_workflow, project: sibling_project, user: owner) }
  let_it_be(:namespace_workflow) { create(:duo_workflows_workflow, project: nil, namespace: group, user: owner) }

  let_it_be(:artifact1) do
    create(:duo_workflow_session_artifact,
      workflow: workflow1,
      workflow_definition: 'software_development',
      workflow_updated_at: 2.hours.ago)
  end

  let_it_be(:artifact2) do
    create(:duo_workflow_session_artifact,
      workflow: workflow2,
      workflow_definition: 'chat',
      workflow_updated_at: 1.hour.ago)
  end

  let_it_be(:sibling_artifact) do
    create(:duo_workflow_session_artifact,
      workflow: sibling_workflow,
      workflow_definition: 'software_development',
      workflow_updated_at: 30.minutes.ago)
  end

  let_it_be(:namespace_artifact) do
    create(:duo_workflow_session_artifact, :with_namespace,
      workflow: namespace_workflow, namespace: group)
  end

  let_it_be(:current_user) { owner }
  let(:query) do
    <<~GRAPHQL
      query {
        project(fullPath: "#{project.full_path}") {
          duoWorkflowSessionArtifacts(first: 10) {
            count
            nodes {
              id
              workflowDefinition
              webPath
              auditEventsCount
              workflowCreatedAt
              project {
                id
                fullPath
              }
            }
            pageInfo {
              hasNextPage
              hasPreviousPage
              startCursor
              endCursor
            }
          }
        }
      }
    GRAPHQL
  end

  subject(:session_artifacts) do
    graphql_data.dig('project', 'duoWorkflowSessionArtifacts')
  end

  before do
    stub_licensed_features(
      custom_roles: true,
      project_level_compliance_dashboard: true,
      group_level_compliance_dashboard: true
    )
    # Force the PostgreSQL finder path so we assert project_namespace scoping on PG.
    allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
  end

  context 'when the user is an authorized project owner' do
    it 'returns only the project artifacts, excluding siblings and group-namespace artifacts',
      :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_nil

      ids = session_artifacts['nodes'].pluck('id')
      expect(session_artifacts['count']).to eq(2)
      expect(ids).to contain_exactly(workflow1.to_global_id.to_s, workflow2.to_global_id.to_s)
      expect(ids).not_to include(sibling_workflow.to_global_id.to_s)
      expect(ids).not_to include(namespace_workflow.to_global_id.to_s)
    end

    it 'returns artifacts ordered most recently updated first' do
      post_graphql(query, current_user: current_user)

      ids = session_artifacts['nodes'].pluck('id')
      expect(ids).to eq([workflow2.to_global_id.to_s, workflow1.to_global_id.to_s])
    end
  end

  context 'when querying with the group-only projectPath filter argument' do
    let(:query) do
      <<~GRAPHQL
        query {
          project(fullPath: "#{project.full_path}") {
            duoWorkflowSessionArtifacts(first: 10, projectPath: "#{project.full_path}") {
              count
            }
          }
        }
      GRAPHQL
    end

    it 'rejects the argument, since the project field is already project-scoped' do
      post_graphql(query, current_user: current_user)

      expect(graphql_errors).to be_present
      expect(graphql_errors.first['message']).to include("doesn't accept argument 'projectPath'")
    end
  end

  # Like the other filters, both user filters are served only by the
  # ClickHouse-backed finder, so the resolver rejects them on the PostgreSQL path.
  context 'when filtering by user without ClickHouse' do
    let(:query) do
      <<~GRAPHQL
        query {
          project(fullPath: "#{project.full_path}") {
            duoWorkflowSessionArtifacts(first: 10, #{filter}) {
              count
              nodes { id }
            }
          }
        }
      GRAPHQL
    end

    context 'with triggeredByUserId' do
      let(:filter) { %(triggeredByUserId: "#{owner.to_global_id}") }

      it 'returns an error explaining that ClickHouse is required', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_include(/requires ClickHouse to be enabled/)
        expect(session_artifacts).to be_nil
      end
    end

    context 'with not: { triggeredByUserId }' do
      let(:filter) { %(not: { triggeredByUserId: "#{owner.to_global_id}" }) }

      it 'returns an error explaining that ClickHouse is required', :aggregate_failures do
        post_graphql(query, current_user: current_user)

        expect(response).to have_gitlab_http_status(:success)
        expect_graphql_errors_to_include(/requires ClickHouse to be enabled/)
        expect(session_artifacts).to be_nil
      end
    end
  end

  context 'when the user is not a member of the project' do
    let(:current_user) { non_member }

    it 'returns null for the field' do
      post_graphql(query, current_user: current_user)

      expect(session_artifacts).to be_nil
    end
  end

  context 'when the agent_artifacts_page feature flag is disabled' do
    before do
      stub_feature_flags(agent_artifacts_page: false)
    end

    it 'returns no artifacts', :aggregate_failures do
      post_graphql(query, current_user: current_user)

      expect(response).to have_gitlab_http_status(:success)
      expect(graphql_errors).to be_nil
      expect(session_artifacts['nodes']).to be_empty
      expect(session_artifacts['count']).to eq(0)
    end
  end

  describe 'workflowId filter and auditEvents field' do
    let_it_be(:chat_author) { create(:user) }
    let_it_be(:chat_workflow) do
      create(:duo_workflows_workflow, :agentic_chat, project: project, user: chat_author)
    end

    let_it_be(:chat_artifact) do
      create(:duo_workflow_session_artifact,
        workflow: chat_workflow,
        workflow_definition: 'chat',
        workflow_updated_at: 10.minutes.ago)
    end

    let_it_be(:chat_event) do
      create(:audit_events_ai_audit_event,
        target_project: project, user: chat_author, workflow_id: chat_workflow.id,
        event_name: 'ai_agent_session_started')
    end

    let(:query) do
      <<~GRAPHQL
        query {
          project(fullPath: "#{project.full_path}") {
            duoWorkflowSessionArtifacts(workflowId: "#{chat_workflow.to_global_id}") {
              nodes {
                id
                auditEvents {
                  nodes { eventName }
                }
              }
            }
          }
        }
      GRAPHQL
    end

    it 'returns only the single filtered session', :aggregate_failures do
      post_graphql(query, current_user: owner)

      nodes = session_artifacts['nodes']
      expect(nodes.length).to eq(1)
      expect(nodes.first['id']).to eq(chat_workflow.to_global_id.to_s)
    end

    context 'when the reviewer is a project Owner but not the chat author' do
      let_it_be(:reviewer) { create(:user) }

      before_all { project.add_owner(reviewer) }

      it 'returns the chat session audit events without a workflow error', :aggregate_failures do
        post_graphql(query, current_user: reviewer)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil

        event_names = session_artifacts.dig('nodes', 0, 'auditEvents', 'nodes').pluck('eventName')
        expect(event_names).to contain_exactly('ai_agent_session_started')
      end
    end

    context 'when ClickHouse is globally enabled' do
      let(:ch_event_rows) do
        [
          {
            'id' => '00000000-0000-0000-0000-000000000001',
            'cloud_event_id' => '00000000-0000-0000-0000-000000000001',
            'event_name' => 'ai_agent_session_started',
            'created_at' => 1.minute.ago.utc.strftime('%Y-%m-%d %H:%M:%S'),
            'workflow_id' => chat_workflow.id.to_s,
            'ip_address' => '203.0.113.7',
            'details' => '{}',
            'author_id' => chat_author.id
          }
        ]
      end

      before do
        allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)

        # The session list is served from the ClickHouse-backed finder when CH is
        # globally enabled. Return the single chat artifact directly to avoid
        # depending on a seeded `siphon_duo_workflows_workflows` table.
        session_ch_finder = instance_double(
          ::Ai::DuoWorkflows::SessionArtifacts::ClickHouseFinder,
          execute: ::Ai::DuoWorkflows::SessionArtifact.id_in(chat_artifact.id)
        )
        allow(::Ai::DuoWorkflows::SessionArtifacts::ClickHouseFinder)
          .to receive(:new).and_return(session_ch_finder)

        events_ch_finder = instance_double(
          ::AuditEvents::AiAuditEvents::ClickHouseFinder, execute: ch_event_rows
        )
        allow(::AuditEvents::AiAuditEvents::ClickHouseFinder)
          .to receive(:new).and_return(events_ch_finder)
      end

      it 'loads chat audit events through the ClickHouse path', :aggregate_failures do
        post_graphql(query, current_user: owner)

        expect(response).to have_gitlab_http_status(:success)
        expect(graphql_errors).to be_nil

        event_names = session_artifacts.dig('nodes', 0, 'auditEvents', 'nodes').pluck('eventName')
        expect(event_names).to eq(%w[ai_agent_session_started])
      end
    end

    context 'when the user lacks read_compliance_dashboard' do
      let_it_be(:developer) { create(:user, developer_of: project) }

      it 'returns no session and no events', :aggregate_failures do
        post_graphql(query, current_user: developer)

        expect(response).to have_gitlab_http_status(:success)
        expect(session_artifacts).to be_nil
      end
    end
  end
end
