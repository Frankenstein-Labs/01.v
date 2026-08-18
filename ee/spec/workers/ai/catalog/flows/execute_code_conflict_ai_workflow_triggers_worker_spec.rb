# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteCodeConflictAiWorkflowTriggersWorker,
  feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) do
    create(:merge_request, source_project: project, target_project: project, author: user)
  end

  let_it_be(:service_account) { create(:service_account) }
  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger,
      project: project,
      user: service_account,
      event_types: [Ai::FlowTrigger::EVENT_TYPES[:merge_request_code_conflict]]
    )
  end

  let(:cloud_event) { MergeRequests::CodeConflictEvent.build(merge_request: merge_request) }
  let(:resource) { merge_request }
  let(:event) { cloud_event }

  let(:wrong_event) do
    MergeRequests::DraftStateChangeEvent.new(
      data: { current_user_id: user.id, merge_request_id: merge_request.id }
    )
  end

  let(:doomed_resource) do
    create(:merge_request, source_project: project, target_project: project, author: user, source_branch: 'doomed')
  end

  let(:doomed_resource_event) { MergeRequests::CodeConflictEvent.build(merge_request: doomed_resource) }

  it_behaves_like 'subscribes to event'
  it_behaves_like 'a cloud events flow trigger worker'
end
