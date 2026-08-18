# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group > Settings > GitLab Duo > Governance > Agent artifacts', :js, :saas,
  feature_category: :compliance_management do
  include SubscriptionPortalHelpers

  let_it_be(:reviewer) { create(:user) }
  let_it_be(:author) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: reviewer) }
  let_it_be(:project) { create(:project, group: group) }

  let_it_be(:workflow) do
    create(:duo_workflows_workflow, :agentic_chat, project: project, user: author)
  end

  let_it_be(:session_artifact) do
    create(:duo_workflow_session_artifact, workflow: workflow)
  end

  let_it_be(:audit_event) do
    create(:audit_events_ai_audit_event,
      target_project: project, user: author, workflow_id: workflow.id,
      event_name: 'ai_agent_session_started')
  end

  before do
    stub_signing_key
    stub_application_setting(gravatar_enabled: false)
    stub_subscription_permissions_data(group.id)
    stub_licensed_features(
      ai_features: true,
      code_suggestions: true,
      group_level_compliance_dashboard: true,
      project_level_compliance_dashboard: true
    )
    sign_in(reviewer)

    visit group_settings_gitlab_duo_governance_index_path(group, tab: 'agent-artifacts')
  end

  it 'lets a compliance reviewer open a Duo Chat session and view its audit events', :aggregate_failures do
    # Wait for the batch-loaded audit-events count to render before clicking; the row
    # appears before that query resolves, and a click mid-rerender is dropped.
    expect(page).to have_testid('audit-events-count', text: '1')

    find_by_testid('agent-artifacts-table-row').click

    within_testid('session-details-drawer') do
      expect(page).to have_testid('event-name', text: 'Agent session started')
      expect(page).to have_no_content(s_('AgentArtifacts|Failed to load audit events.'))
    end
  end
end
