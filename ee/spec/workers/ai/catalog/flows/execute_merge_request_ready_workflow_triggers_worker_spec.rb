# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteMergeRequestReadyWorkflowTriggersWorker,
  feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:service_account) { create(:service_account) }
  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger,
      project: project,
      user: service_account,
      event_types: [Ai::FlowTrigger::EVENT_TYPES[:merge_request_ready]]
    )
  end

  let(:cloud_event) do
    MergeRequests::ReadyEvent.build(
      merge_request: merge_request,
      current_user: user
    )
  end

  let(:resource) { merge_request }
  let(:event) { cloud_event }

  let(:wrong_event) do
    MergeRequests::DraftStateChangeEvent.new(
      data: { current_user_id: user.id, merge_request_id: merge_request.id }
    )
  end

  let(:doomed_resource) do
    create(:merge_request, source_project: project, target_project: project, source_branch: 'doomed-branch')
  end

  let(:doomed_resource_event) do
    MergeRequests::ReadyEvent.build(merge_request: doomed_resource, current_user: user)
  end

  it_behaves_like 'subscribes to event'
  it_behaves_like 'a cloud events flow trigger worker'
end
