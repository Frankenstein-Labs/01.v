# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Flows::ExecuteMergeRequestMergedWorkflowTriggersWorker,
  feature_category: :code_suggestions do
  let_it_be(:merged_by) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:merge_request) do
    create(:merge_request, :with_merged_metrics,
      source_project: project, target_project: project, merged_by: merged_by)
  end

  let_it_be(:service_account) { create(:service_account) }
  let_it_be(:flow_trigger) do
    create(:ai_flow_trigger,
      project: project,
      user: service_account,
      event_types: [Ai::FlowTrigger::EVENT_TYPES[:merge_request]],
      filter: {
        'merge_request' => {
          'rules' => [{ 'field' => 'action', 'operator' => 'in', 'value' => %w[merged] }]
        }
      }
    )
  end

  let_it_be(:developer_flow_session) do
    create(:duo_workflows_workflow,
      project: project,
      user: merged_by,
      merge_request: merge_request,
      workflow_definition: ::Ai::Catalog::FoundationalFlow::Definitions::Developer::REFERENCE)
  end

  let(:event) { MergeRequests::MergedEvent.new(data: { merge_request_id: merge_request.id }) }

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    subject(:handle_event) { described_class.new.handle_event(event) }

    let(:run_service) { instance_double(Ai::FlowTriggers::RunService, execute: nil) }
    let(:filter_evaluator) { instance_double(Ai::FlowTriggers::FilterEvaluator, allowed?: true) }

    before do
      allow(Ai::FlowTriggers::FilterEvaluator).to receive(:new).and_return(filter_evaluator)
      allow(Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
    end

    it 'starts the flow as the user who merged the merge request', :aggregate_failures do
      expect(Ai::FlowTriggers::FilterEvaluator).to receive(:new).with(
        flow_trigger: flow_trigger,
        hook_scope: :merge_request,
        data: { 'action' => 'merged' }
      ).and_return(filter_evaluator)
      expect(Ai::FlowTriggers::RunService).to receive(:new).with(
        project: project,
        current_user: merged_by,
        flow_trigger: flow_trigger,
        resource: merge_request
      ).and_return(run_service)
      expect(run_service).to receive(:execute).with(
        {
          input: merge_request.iid.to_s,
          event: :merge_request,
          action: 'merged',
          session_ids: [developer_flow_session.id]
        }
      )

      handle_event
    end

    context 'when the merge_request_merged_flow_trigger feature flag is disabled for the project' do
      before do
        stub_feature_flags(merge_request_merged_flow_trigger: false)
      end

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the merge_request_merged_memory_distillation feature flag is disabled for the project' do
      before do
        stub_feature_flags(merge_request_merged_memory_distillation: false)
      end

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the merge request has no developer flow session' do
      let_it_be(:other_merge_request) do
        create(:merge_request, :with_merged_metrics, :unique_branches,
          source_project: project, target_project: project, merged_by: merged_by)
      end

      let(:event) { MergeRequests::MergedEvent.new(data: { merge_request_id: other_merge_request.id }) }

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end

      context 'when the merge request has a session for another flow' do
        before_all do
          create(:duo_workflows_workflow,
            project: project,
            user: merged_by,
            merge_request: other_merge_request,
            workflow_definition: 'software_development')
        end

        it 'does not start a flow' do
          expect(run_service).not_to receive(:execute)

          handle_event
        end
      end
    end

    context 'when the merge request has no metrics' do
      before do
        allow_next_found_instance_of(MergeRequest) do |found_merge_request|
          allow(found_merge_request).to receive(:metrics).and_return(nil)
        end
      end

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the merge request no longer exists' do
      let(:event) { MergeRequests::MergedEvent.new(data: { merge_request_id: non_existing_record_id }) }

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end
  end
end
