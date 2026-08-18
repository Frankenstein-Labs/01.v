# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::UpdateWorkflowStatusEventWorker, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:workload) { create(:ci_workload, project: project, pipeline: pipeline) }
  let(:status) { 'finished' }
  let(:data) do
    { workload_id: workload.id, status: status }
  end

  let(:event) { Ci::Workloads::WorkloadFinishedEvent.new(data: data) }

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    subject(:handle_event) { consume_event(subscriber: described_class, event: event) }

    context 'when workload cannot be found' do
      let(:data) do
        { workload_id: non_existing_record_id, status: status }
      end

      it 'does not call UpdateWorkflowStatusService or enqueue GenerateWorkflowSummaryWorker' do
        expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)
        expect(Ai::DuoWorkflows::GenerateWorkflowSummaryWorker).not_to receive(:perform_async)

        expect { handle_event }.not_to raise_error
      end
    end

    context 'when workload is found' do
      context 'when workflow cannot be found' do
        it 'does not call UpdateWorkflowStatusService or enqueue GenerateWorkflowSummaryWorker' do
          expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)
          expect(Ai::DuoWorkflows::GenerateWorkflowSummaryWorker).not_to receive(:perform_async)

          expect { handle_event }.not_to raise_error
        end
      end

      context 'when workflow is found' do
        let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }

        before do
          create(:duo_workflows_workload, workflow: workflow, workload: workload, project: project)
          pipeline.update_columns(created_at: 3.minutes.ago, finished_at: Time.current, status: 'success')
        end

        context 'when workload status is failed' do
          let(:status) { 'failed' }

          it 'calls UpdateWorkflowStatusService with drop event' do
            expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).to receive(:new)
              .with(workflow: workflow, status_event: 'drop', current_user: workflow.user, summary: anything)
              .and_call_original

            handle_event
          end

          context 'when a build has a failure reason' do
            let!(:build) { create(:ci_build, :failed, pipeline: pipeline, failure_reason: :script_failure) }

            it 'passes the failure reason as summary to UpdateWorkflowStatusService' do
              expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).to receive(:new)
                .with(hash_including(summary: "Error during Session: script_failure"))
                .and_call_original

              handle_event
            end
          end
        end

        context 'when workload status is finished' do
          let(:status) { 'finished' }

          it 'does not call UpdateWorkflowStatusService' do
            expect(Ai::DuoWorkflows::UpdateWorkflowStatusService).not_to receive(:new)

            handle_event
          end
        end

        context 'when the workflow fails with a failure reason' do
          let(:status) { 'failed' }
          let!(:build) { create(:ci_build, :failed, pipeline: pipeline, failure_reason: :script_failure) }

          before do
            allow_next_instance_of(Ai::DuoWorkflows::UpdateWorkflowStatusService) do |service|
              allow(service).to receive(:execute).and_return(ServiceResponse.success)
            end
          end

          it 'enqueues GenerateWorkflowSummaryWorker' do
            expect(Ai::DuoWorkflows::GenerateWorkflowSummaryWorker).to receive(:perform_async).with(workflow.id)

            handle_event
          end
        end

        context 'when the workflow fails with no failure reason' do
          let(:status) { 'failed' }

          it 'does not enqueue GenerateWorkflowSummaryWorker' do
            expect(Ai::DuoWorkflows::GenerateWorkflowSummaryWorker).not_to receive(:perform_async)

            handle_event
          end
        end

        context 'when the workflow finishes successfully' do
          let(:status) { 'finished' }

          it 'does not enqueue GenerateWorkflowSummaryWorker' do
            expect(Ai::DuoWorkflows::GenerateWorkflowSummaryWorker).not_to receive(:perform_async)

            handle_event
          end
        end

        it 'emits workload completion metrics' do
          expect(Gitlab::AppLogger).to receive(:info).with(
            hash_including(
              message: 'duo_workflow_workload_completed',
              pipeline_id: pipeline.id,
              pipeline_status: 'success',
              workflow_id: workflow.id,
              workflow_definition: workflow.workflow_definition
            )
          )

          handle_event
        end
      end
    end
  end
end
