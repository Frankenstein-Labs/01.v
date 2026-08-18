# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Messaging::CallbackWorker, feature_category: :duo_agent_platform do
  describe '#handle_event' do
    subject(:worker) { described_class.new }

    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, developer_of: project) }

    let(:callback_context) { { 'adapter' => 'test_adapter', 'channel_id' => 'C123' } }

    let(:workflow) do
      create(:duo_workflows_workflow,
        user: user,
        project: project,
        messaging_callback_context: callback_context)
    end

    let(:workload) { create(:ci_workload) }

    let(:event) do
      Ci::Workloads::WorkloadFinishedEvent.new(
        data: { workload_id: workload.id, status: status }
      )
    end

    let(:status) { 'finished' }

    let(:test_adapter_class) do
      Class.new(Ai::Messaging::Adapters::Base) do
        attr_reader :delivered_results, :delivered_errors, :started_flows, :completed_flows, :failed_flows

        def self.adapter_key
          'test_adapter'
        end

        def self.from_callback_context(_ctx)
          new
        end

        def initialize
          @delivered_results = []
          @delivered_errors = []
          @started_flows = []
          @completed_flows = []
          @failed_flows = []
        end

        def on_flow_started(callback_context:, workflow:)
          @started_flows << { callback_context: callback_context, workflow: workflow }
        end

        def build_callback_context
          {}
        end

        def deliver_result(callback_context:, message:, workflow:)
          @delivered_results << { callback_context: callback_context, message: message, workflow: workflow }
          true
        end

        def deliver_error(callback_context:, error:)
          @delivered_errors << { callback_context: callback_context, error: error }
        end

        def on_flow_completed(callback_context:, workflow:)
          @completed_flows << { callback_context: callback_context, workflow: workflow }
        end

        def on_flow_failed(callback_context:, error:, workflow: nil)
          @failed_flows << { callback_context: callback_context, error: error, workflow: workflow }
          deliver_error(callback_context: callback_context, error: error)
        end
      end
    end

    let(:test_adapter_instance) { test_adapter_class.new }

    before do
      create(:duo_workflows_workload, workflow: workflow, workload: workload, project: project)

      stub_const('Ai::Messaging::AdapterRegistry::ADAPTERS', { 'test_adapter' => test_adapter_class }.freeze)
      allow(test_adapter_class).to receive(:from_callback_context).and_return(test_adapter_instance)
    end

    context 'when workload does not exist' do
      let(:event) do
        Ci::Workloads::WorkloadFinishedEvent.new(
          data: { workload_id: non_existing_record_id, status: 'finished' }
        )
      end

      it 'returns early without error' do
        expect { worker.handle_event(event) }.not_to raise_error
      end
    end

    context 'when workflow has no messaging_callback_context' do
      before do
        workflow.update_column(:messaging_callback_context, nil)
      end

      it 'skips processing' do
        worker.handle_event(event)
        expect(test_adapter_instance.delivered_results).to be_empty
      end
    end

    context 'when adapter is not registered' do
      let(:callback_context) { { 'adapter' => 'unknown', 'channel_id' => 'C123' } }

      it 'logs a warning and skips processing' do
        expect(Gitlab::AppLogger).to receive(:warn).with(hash_including(adapter: 'unknown'))

        worker.handle_event(event)
        expect(test_adapter_instance.delivered_results).to be_empty
      end
    end

    context 'when flow failed' do
      let(:status) { 'failed' }

      it 'calls on_flow_failed with :flow_failed and the workflow' do
        worker.handle_event(event)

        expect(test_adapter_instance.failed_flows).to contain_exactly(
          hash_including(error: :flow_failed, workflow: workflow)
        )
      end
    end

    context 'when handling a WorkflowStartedEvent' do
      let(:event) do
        Ai::DuoWorkflows::WorkflowStartedEvent.new(data: { workflow_id: workflow.id })
      end

      it 'calls on_flow_started with the workflow' do
        worker.handle_event(event)

        expect(test_adapter_instance.started_flows).to contain_exactly(
          hash_including(workflow: workflow)
        )
      end

      context 'when the workflow does not exist' do
        let(:event) do
          Ai::DuoWorkflows::WorkflowStartedEvent.new(data: { workflow_id: non_existing_record_id })
        end

        it 'returns early without error' do
          expect { worker.handle_event(event) }.not_to raise_error
          expect(test_adapter_instance.started_flows).to be_empty
        end
      end

      context 'when the workflow has no messaging_callback_context' do
        before do
          workflow.update_column(:messaging_callback_context, nil)
        end

        it 'skips processing' do
          worker.handle_event(event)
          expect(test_adapter_instance.started_flows).to be_empty
        end
      end

      context 'when on_flow_started raises an error' do
        before do
          allow(test_adapter_instance).to receive(:on_flow_started).and_raise(StandardError, 'started hook failed')
        end

        it 'tracks the exception without re-raising' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)

          expect { worker.handle_event(event) }.not_to raise_error
        end
      end
    end

    context 'when deliver_result raises an error' do
      let(:event) do
        Ai::DuoWorkflows::WorkflowFinishedEvent.new(data: { workflow_id: workflow.id })
      end

      before do
        create(:duo_workflows_checkpoint,
          workflow: workflow,
          project: project,
          checkpoint: {
            'channel_values' => {
              'ui_chat_log' => [
                { 'message_type' => 'agent', 'content' => 'Result' }
              ]
            }
          })

        allow(test_adapter_instance).to receive(:deliver_result).and_raise(StandardError, 'delivery failed')
      end

      it 'tracks the exception and leaves the flow open for the backstop', :aggregate_failures do
        # Returns its trackers, as the real method does: a swallowed error must read as a
        # failed delivery on the tracker's return value, not on a happens-to-be-nil stub.
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)
          .at_least(:once).and_return([::Gitlab::ErrorTracking::Logger])

        worker.handle_event(event)

        expect(test_adapter_instance.completed_flows).to be_empty
        expect(workflow.reload.messaging_callback_context).not_to have_key('delivered_at')
      end
    end

    context 'when on_flow_completed raises an error' do
      let(:event) do
        Ai::DuoWorkflows::WorkflowFinishedEvent.new(data: { workflow_id: workflow.id })
      end

      before do
        create(:duo_workflows_checkpoint,
          workflow: workflow,
          project: project,
          checkpoint: {
            'channel_values' => {
              'ui_chat_log' => [
                { 'message_type' => 'agent', 'content' => 'Result' }
              ]
            }
          })

        allow(test_adapter_instance).to receive(:on_flow_completed).and_raise(StandardError, 'completed hook failed')
      end

      it 'tracks the exception without re-raising' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)

        expect { worker.handle_event(event) }.not_to raise_error
      end
    end

    context 'when handling a WorkflowFinishedEvent' do
      let(:finished_event) do
        Ai::DuoWorkflows::WorkflowFinishedEvent.new(data: { workflow_id: workflow.id })
      end

      context 'with a final agent message in checkpoints' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'message_type' => 'user', 'content' => 'Fix CI' },
                  { 'message_type' => 'agent', 'content' => 'I fixed the pipeline.' }
                ]
              }
            })
        end

        it 'delivers the result to the adapter', :aggregate_failures do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.delivered_results).to contain_exactly(
            hash_including(message: 'I fixed the pipeline.', workflow: workflow)
          )
        end

        it 'calls on_flow_completed' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.completed_flows).to contain_exactly(
            hash_including(workflow: workflow)
          )
        end

        it 'records the delivery on the workflow' do
          worker.handle_event(finished_event)

          expect(workflow.reload.messaging_callback_context['delivered_at']).to be_present
        end

        it 'does not deliver again on the WorkloadFinishedEvent' do
          worker.handle_event(finished_event)
          worker.handle_event(event)

          expect(test_adapter_instance.delivered_results.size).to eq(1)
        end

        it 'does not deliver again when the event is redelivered' do
          worker.handle_event(finished_event)
          worker.handle_event(finished_event)

          expect(test_adapter_instance.delivered_results.size).to eq(1)
        end

        context 'when the adapter reports a failed delivery' do
          before do
            allow(test_adapter_instance).to receive(:deliver_result).and_return(false)
          end

          it 'records nothing and does not mark the flow completed', :aggregate_failures do
            worker.handle_event(finished_event)

            expect(workflow.reload.messaging_callback_context).not_to have_key('delivered_at')
            expect(test_adapter_instance.completed_flows).to be_empty
          end

          it 'delivers the answer on the WorkloadFinishedEvent instead', :aggregate_failures do
            worker.handle_event(finished_event)
            allow(test_adapter_instance).to receive(:deliver_result).and_call_original

            worker.handle_event(event)

            expect(test_adapter_instance.delivered_results).to contain_exactly(
              hash_including(message: 'I fixed the pipeline.', workflow: workflow)
            )
            expect(test_adapter_instance.completed_flows).to contain_exactly(
              hash_including(workflow: workflow)
            )
          end
        end
      end

      context 'when the last agent message is empty but an earlier one has content' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'message_type' => 'user', 'content' => 'Fix CI' },
                  { 'message_type' => 'agent', 'content' => 'I fixed the pipeline.' },
                  { 'message_type' => 'agent', 'content' => '' }
                ]
              }
            })
        end

        it 'delivers the last non-empty agent message' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.delivered_results).to contain_exactly(
            hash_including(message: 'I fixed the pipeline.')
          )
        end
      end

      context 'when the last agent message has nil content but an earlier one has content' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'message_type' => 'user', 'content' => 'Fix CI' },
                  { 'message_type' => 'agent', 'content' => 'I fixed the pipeline.' },
                  { 'message_type' => 'agent', 'content' => nil }
                ]
              }
            })
        end

        it 'delivers the last non-empty agent message' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.delivered_results).to contain_exactly(
            hash_including(message: 'I fixed the pipeline.')
          )
        end
      end

      context 'when the last agent message has tool_calls but an earlier one has content' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'message_type' => 'user', 'content' => 'Fix CI' },
                  { 'message_type' => 'agent', 'content' => 'I fixed the pipeline.' },
                  { 'message_type' => 'agent', 'content' => 'Marking todos done',
                    'tool_calls' => [{ 'name' => 'complete_todo' }] }
                ]
              }
            })
        end

        it 'delivers the last agent message without tool calls' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.delivered_results).to contain_exactly(
            hash_including(message: 'I fixed the pipeline.')
          )
        end
      end

      context 'when all agent messages have empty content' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'message_type' => 'user', 'content' => 'Fix CI' },
                  { 'message_type' => 'agent', 'content' => '' },
                  { 'message_type' => 'agent', 'content' => nil }
                ]
              }
            })
        end

        it 'calls on_flow_failed with :no_response and the workflow' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.failed_flows).to contain_exactly(
            hash_including(error: :no_response, workflow: workflow)
          )
        end

        it 'does not report the error again on the WorkloadFinishedEvent' do
          worker.handle_event(finished_event)
          worker.handle_event(event)

          expect(test_adapter_instance.failed_flows.size).to eq(1)
        end
      end

      context 'when all agent messages have tool_calls' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'message_type' => 'user', 'content' => 'Fix CI' },
                  { 'message_type' => 'agent', 'content' => 'Working',
                    'tool_calls' => [{ 'name' => 'do_thing' }] }
                ]
              }
            })
        end

        it 'calls on_flow_failed with :no_response and the workflow' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.failed_flows).to contain_exactly(
            hash_including(error: :no_response, workflow: workflow)
          )
        end
      end

      context 'when the notifications read gate is on' do
        let(:workflow) do
          create(:duo_workflows_workflow,
            user: user, project: project, messaging_callback_context: callback_context,
            incremental_checkpoints_enabled: true)
        end

        before do
          create(:duo_workflows_checkpoint_header, workflow: workflow, thread_ts: 'ts-1', parent_ts: nil,
            current_thread: 0)
          header_log = [{ 'message_type' => 'user', 'content' => 'header' }]
          create(:duo_workflows_checkpoint, workflow: workflow, project: project, thread_ts: 'ts-1',
            current_thread: 0, checkpoint: { 'channel_values' => { 'ui_chat_log' => header_log } })
          create(:duo_workflows_checkpoint_blob,
            workflow: workflow, thread_ts: 'ts-1', current_thread: 0, channel: 'ui_chat_log',
            version: '1', write_type: 'json', step_action: 'conversation', workflow_created_at: workflow.created_at,
            data: Zlib::Deflate.deflate(::Gitlab::Json.dump(
              [{ 'message_type' => 'agent', 'content' => 'From incremental blob.' }])))
          stub_feature_flags(duo_workflow_read_incremental_checkpoints: project, dw_read_blobs_notifications: project)
        end

        it 'delivers the message reconstructed from incremental blobs' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.delivered_results).to contain_exactly(
            hash_including(message: 'From incremental blob.')
          )
        end
      end

      context 'when latest checkpoint has nil checkpoint data' do
        let(:checkpoint_record) do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: { 'channel_values' => {} })
        end

        before do
          checkpoint_record
          allow(checkpoint_record).to receive(:checkpoint).and_return(nil)
          allow(workflow.checkpoints).to receive(:latest).and_return(checkpoint_record)
        end

        it 'calls on_flow_failed with :no_response and the workflow' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.failed_flows).to contain_exactly(
            hash_including(error: :no_response, workflow: workflow)
          )
        end
      end

      context 'when checkpoint has no channel_values' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: { 'some_other_key' => 'value' })
        end

        it 'calls on_flow_failed with :no_response and the workflow' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.failed_flows).to contain_exactly(
            hash_including(error: :no_response, workflow: workflow)
          )
        end
      end

      context 'when chat log contains only user messages' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: {
              'channel_values' => {
                'ui_chat_log' => [
                  { 'message_type' => 'user', 'content' => 'Fix CI' }
                ]
              }
            })
        end

        it 'calls on_flow_failed with :no_response and the workflow' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.failed_flows).to contain_exactly(
            hash_including(error: :no_response, workflow: workflow)
          )
        end
      end

      context 'when checkpoints have no agent message' do
        before do
          create(:duo_workflows_checkpoint,
            workflow: workflow,
            project: project,
            checkpoint: { 'channel_values' => { 'ui_chat_log' => [] } })
        end

        it 'calls on_flow_failed with :no_response and the workflow' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.failed_flows).to contain_exactly(
            hash_including(error: :no_response, workflow: workflow)
          )
        end
      end

      context 'when no checkpoints exist' do
        it 'calls on_flow_failed with :no_response and the workflow' do
          worker.handle_event(finished_event)

          expect(test_adapter_instance.failed_flows).to contain_exactly(
            hash_including(error: :no_response, workflow: workflow)
          )
        end
      end

      context 'when the workflow does not exist' do
        let(:finished_event) do
          Ai::DuoWorkflows::WorkflowFinishedEvent.new(data: { workflow_id: non_existing_record_id })
        end

        it 'returns early without error' do
          expect { worker.handle_event(finished_event) }.not_to raise_error
          expect(test_adapter_instance.delivered_results).to be_empty
        end
      end

      context 'when the workflow has no messaging_callback_context' do
        before do
          workflow.update_column(:messaging_callback_context, nil)
        end

        it 'skips processing' do
          worker.handle_event(finished_event)
          expect(test_adapter_instance.delivered_results).to be_empty
        end
      end

      context 'when a WorkloadFinishedEvent reports a non-finished status' do
        let(:status) { 'failed' }

        context 'and the workflow already finished' do
          before do
            finished_value = Ai::DuoWorkflows::Workflow.state_machines[:status].states[:finished].value
            workflow.update_column(:status, finished_value)
          end

          context 'and the reply was already delivered' do
            before do
              workflow.merge_messaging_callback_context!('delivered_at' => Time.current.utc.iso8601)
            end

            it 'posts nothing over the already-delivered reply', :aggregate_failures do
              worker.handle_event(event)

              expect(test_adapter_instance.failed_flows).to be_empty
              expect(test_adapter_instance.delivered_results).to be_empty
            end
          end

          context 'and the reply was never delivered' do
            before do
              create(:duo_workflows_checkpoint,
                workflow: workflow,
                project: project,
                checkpoint: {
                  'channel_values' => {
                    'ui_chat_log' => [
                      { 'message_type' => 'agent', 'content' => 'I fixed the pipeline.' }
                    ]
                  }
                })
            end

            it 'delivers the answer rather than a failure', :aggregate_failures do
              worker.handle_event(event)

              expect(test_adapter_instance.delivered_results).to contain_exactly(
                hash_including(message: 'I fixed the pipeline.', workflow: workflow)
              )
              expect(test_adapter_instance.failed_flows).to be_empty
            end
          end
        end

        context 'and the workflow has not finished' do
          it 'delivers the failure' do
            worker.handle_event(event)

            expect(test_adapter_instance.failed_flows).to contain_exactly(
              hash_including(error: :flow_failed, workflow: workflow)
            )
          end
        end
      end
    end
  end

  describe 'worker configuration' do
    it { expect(described_class.get_feature_category).to eq(:duo_agent_platform) }

    it 'declares external dependencies' do
      expect(described_class.worker_has_external_dependencies?).to be(true)
    end
  end

  describe 'event subscription' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, developer_of: project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, user: user, project: project) }
    let_it_be(:workload) { create(:ci_workload) }

    before do
      create(:duo_workflows_workload, workflow: workflow, workload: workload, project: project)
    end

    it_behaves_like 'subscribes to event' do
      let(:event) do
        Ci::Workloads::WorkloadFinishedEvent.new(data: { workload_id: workload.id, status: 'finished' })
      end
    end

    it_behaves_like 'subscribes to event' do
      let(:event) { Ai::DuoWorkflows::WorkflowStartedEvent.new(data: { workflow_id: workflow.id }) }
    end

    it_behaves_like 'subscribes to event' do
      let(:event) { Ai::DuoWorkflows::WorkflowFinishedEvent.new(data: { workflow_id: workflow.id }) }
    end
  end
end
