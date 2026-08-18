# frozen_string_literal: true

# Shared examples for workers that include Ai::CloudEventsFlowTriggerWorker.
#
# Required `let` definitions:
#   - `user`: the user who triggered the event
#   - `project`: the project the resource belongs to
#   - `resource`: the domain object (e.g. merge_request, work_item)
#   - `flow_trigger`: an `ai_flow_trigger` record for the project
#   - `cloud_event`: the cloud event instance passed to `handle_event`
#   - `wrong_event`: an event of the wrong type (to test early return)
#   - `doomed_resource`: a persisted resource that will be destroyed by the shared example
#   - `doomed_resource_event`: a cloud event built from `doomed_resource`

RSpec.shared_examples 'a cloud events flow trigger worker' do
  let(:filter_evaluator) { instance_double(Ai::FlowTriggers::FilterEvaluator, allowed?: true) }
  let(:run_service) { instance_double(Ai::FlowTriggers::RunService) }

  let(:hook_scope) { described_class.event_type }
  let(:filter_data) do
    if described_class.respond_to?(:action)
      { 'action' => described_class.action }
    else
      {}
    end
  end

  let(:run_params) do
    params = { input: resource.iid.to_s, event: described_class.event_type }
    params[:action] = described_class.action if described_class.respond_to?(:action)
    params
  end

  before do
    allow(Ai::FlowTriggers::FilterEvaluator).to receive(:new).and_return(filter_evaluator)
    allow(Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
    allow(run_service).to receive(:execute)
  end

  describe '#handle_event' do
    subject(:handle_event) { described_class.new.handle_event(cloud_event) }

    context 'when the event is the wrong type' do
      let(:cloud_event) { wrong_event }

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the resource does not exist' do
      let(:cloud_event) { doomed_resource_event }

      before do
        doomed_resource.destroy!
      end

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the user does not exist' do
      before do
        allow(cloud_event).to receive(:current_user).and_return(nil)
      end

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the filter does not match' do
      let(:filter_evaluator) { instance_double(Ai::FlowTriggers::FilterEvaluator, allowed?: false) }

      it 'does not start a flow' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when flow triggers exist and conditions are met' do
      it 'evaluates the filter and starts a flow with the correct arguments', :aggregate_failures do
        expect(Ai::FlowTriggers::FilterEvaluator).to receive(:new).with(
          flow_trigger: flow_trigger,
          hook_scope: hook_scope,
          data: filter_data
        ).and_return(filter_evaluator)

        expect(Ai::FlowTriggers::RunService).to receive(:new).with(
          project: project,
          current_user: user,
          flow_trigger: flow_trigger,
          resource: resource
        ).and_return(run_service)

        expect(run_service).to receive(:execute).with(run_params)

        handle_event
      end

      context 'when RunService raises an error' do
        it 'tracks the exception and continues' do
          allow(run_service).to receive(:execute).and_raise(StandardError.new('boom'))

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            instance_of(StandardError),
            hash_including(
              flow_trigger_id: flow_trigger.id,
              resource_id: resource.id,
              container_id: project.id
            )
          )

          handle_event
        end
      end
    end
  end
end
