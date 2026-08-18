# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteWorkItemStatusChangedWorkflowTriggersWorker,
  feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:work_item) { create(:work_item, project: project, author: user) }
  let_it_be(:status) { ::WorkItems::Statuses::SystemDefined::Status.find(2) }
  let_it_be(:service_account) { create(:service_account) }
  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger,
      project: project,
      user: service_account,
      event_types: [::Ai::FlowTrigger::EVENT_TYPES[:work_item]]
    )
  end

  let(:cloud_event) { ::WorkItems::StatusChangedEvent.build(work_item: work_item, current_user: user, status: status) }
  let(:resource) { work_item }
  let(:event) { cloud_event }

  let(:wrong_event) do
    ::MergeRequests::DraftStateChangeEvent.new(
      data: { current_user_id: user.id, merge_request_id: non_existing_record_id, new_draft_status: false }
    )
  end

  let(:doomed_resource) { create(:work_item, project: project) }

  let(:doomed_resource_event) do
    ::WorkItems::StatusChangedEvent.build(work_item: doomed_resource, current_user: user, status: status)
  end

  it_behaves_like 'subscribes to event'
  it_behaves_like 'a cloud events flow trigger worker'

  describe '#handle_event' do
    subject(:handle_event) { described_class.new.handle_event(cloud_event) }

    let(:run_service) { instance_double(::Ai::FlowTriggers::RunService) }
    let(:filter_evaluator) { instance_double(::Ai::FlowTriggers::FilterEvaluator, allowed?: true) }

    before do
      allow(::Ai::FlowTriggers::FilterEvaluator).to receive(:new).and_return(filter_evaluator)
      allow(::Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
      allow(run_service).to receive(:execute)
    end

    context 'when the work item has no project (group-level epic)' do
      let_it_be(:group) { create(:group) }
      let_it_be(:epic) { create(:work_item, :epic, namespace: group, author: user) }

      let(:cloud_event) do
        ::WorkItems::StatusChangedEvent.build(work_item: epic, current_user: user, status: status)
      end

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end
  end
end
