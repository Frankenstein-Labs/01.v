# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::AiAuditEvents::PostgresqlFinder, feature_category: :duo_agent_platform do
  let_it_be(:workflow) { create(:duo_workflows_workflow) }
  let_it_be(:other_workflow) { create(:duo_workflows_workflow) }

  let_it_be(:event_oldest) do
    create(:audit_events_ai_audit_event, workflow_id: workflow.id, created_at: 3.minutes.ago)
  end

  let_it_be(:event_middle) do
    create(:audit_events_ai_audit_event, workflow_id: workflow.id, created_at: 2.minutes.ago)
  end

  let_it_be(:event_newest) do
    create(:audit_events_ai_audit_event, workflow_id: workflow.id, created_at: 1.minute.ago)
  end

  let_it_be(:event_other_workflow) do
    create(:audit_events_ai_audit_event, workflow_id: other_workflow.id)
  end

  subject(:execute) { described_class.new(workflow: workflow).execute }

  it 'returns audit events scoped to the workflow, most recent first' do
    expect(execute).to eq([event_newest, event_middle, event_oldest])
  end

  it 'does not include events from other workflows' do
    expect(execute).not_to include(event_other_workflow)
  end
end
