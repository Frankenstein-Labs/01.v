# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteMergeRequestApprovedWorkflowTriggersWorker, feature_category: :code_suggestions do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:service_account) { create(:service_account) }
  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger,
      project: project,
      user: service_account,
      event_types: [Ai::FlowTrigger::EVENT_TYPES[:merge_request]]
    )
  end

  let(:approved_at) { Time.zone.parse('2026-05-08T10:00:00Z') }
  let(:approval_state) { instance_double(ApprovalState, approved?: true) }
  let(:approvals_relation) { instance_double(ActiveRecord::Relation) }

  let(:cloud_event) do
    MergeRequests::ApprovedCloudEvent.build(
      merge_request: merge_request,
      current_user: user,
      approval: instance_double(Approval, created_at: approved_at)
    )
  end

  let(:resource) { merge_request }
  let(:event) { cloud_event }

  let(:wrong_event) do
    MergeRequests::ApprovedEvent.new(
      data: {
        current_user_id: user.id,
        merge_request_id: merge_request.id,
        approved_at: approved_at.iso8601
      }
    )
  end

  let(:doomed_resource) do
    create(:merge_request, source_project: project, target_project: project, source_branch: 'doomed-branch')
  end

  let(:doomed_resource_event) do
    MergeRequests::ApprovedCloudEvent.build(
      merge_request: doomed_resource,
      current_user: user,
      approval: instance_double(Approval, created_at: approved_at)
    )
  end

  before do
    allow_next_found_instance_of(MergeRequest) do |mr|
      allow(mr).to receive_messages(
        approval_state: approval_state,
        approvals: approvals_relation
      )
    end
    allow(approvals_relation).to receive(:maximum).with(:created_at).and_return(approved_at)
  end

  it_behaves_like 'subscribes to event'
  it_behaves_like 'a cloud events flow trigger worker'

  describe '#handle_event' do
    subject(:handle_event) { described_class.new.handle_event(cloud_event) }

    let(:run_service) { instance_double(Ai::FlowTriggers::RunService) }
    let(:filter_evaluator) { instance_double(Ai::FlowTriggers::FilterEvaluator, allowed?: true) }

    before do
      allow(Ai::FlowTriggers::FilterEvaluator).to receive(:new).and_return(filter_evaluator)
      allow(Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
      allow(run_service).to receive(:execute)
    end

    context 'with approval-threshold checks' do
      context 'when the MR is not yet fully approved' do
        let(:approval_state) { instance_double(ApprovalState, approved?: false) }

        it 'does not dispatch flow triggers' do
          expect(run_service).not_to receive(:execute)

          handle_event
        end
      end

      context 'when a later approval exists (this approval did not cross the threshold)' do
        before do
          allow(approvals_relation).to receive(:maximum).with(:created_at)
            .and_return(approved_at + 1.minute)
        end

        it 'does not dispatch flow triggers' do
          expect(run_service).not_to receive(:execute)

          handle_event
        end
      end
    end
  end
end
