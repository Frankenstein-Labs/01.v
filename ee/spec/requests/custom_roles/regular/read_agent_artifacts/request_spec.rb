# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with read_agent_artifacts custom role', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group, reload: true) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:role) do
    create(:member_role, :guest, :read_agent_artifacts, namespace: group)
  end

  let_it_be(:membership) do
    create(:group_member, :guest, member_role: role, user: current_user, group: group)
  end

  let_it_be(:workflow_owner) { create(:user) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project, user: workflow_owner) }
  let_it_be(:audit_event) do
    create(:audit_events_ai_audit_event,
      target_project: project, user: workflow_owner, workflow_id: workflow.id,
      event_name: 'ai_agent_session_started')
  end

  let(:compliance_features) do
    {
      custom_roles: true,
      project_level_compliance_dashboard: true,
      group_level_compliance_dashboard: true
    }
  end

  before do
    stub_licensed_features(compliance_features)
    stub_feature_flags(agent_artifacts_page: true)
    # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
    allow_any_instance_of(User).to receive_messages(allowed_to_use?: true, allowed_to_use_for_resource?: true)
    # rubocop:enable RSpec/AnyInstanceOf
    allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(any_args).and_return(true)
    allow(::Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
    # The agent artifacts page hits the subscription portal for the DAP
    # feature credits check on render. Stub it so the spec does not need
    # network access.
    stub_request(:head, %r{https://customers\.staging\.gitlab\.com/api/v1/consumers/resolve})
      .to_return(status: 200, body: "", headers: {})

    sign_in(current_user)
  end

  describe 'GraphQL duoWorkflow.auditEvents' do
    let(:query) do
      fields = <<~GRAPHQL
        nodes {
          id
          auditEvents { nodes { id eventName } }
        }
      GRAPHQL
      graphql_query_for('duoWorkflowWorkflows',
        { workflow_id: workflow.to_global_id.to_s },
        fields)
    end

    it 'returns audit events for a workflow the user does not own' do
      post_graphql(query, current_user: current_user)

      events = graphql_data.dig('duoWorkflowWorkflows', 'nodes', 0, 'auditEvents', 'nodes')
      expect(events.length).to eq(1)
      expect(events.first['eventName']).to eq('ai_agent_session_started')
    end
  end
end
