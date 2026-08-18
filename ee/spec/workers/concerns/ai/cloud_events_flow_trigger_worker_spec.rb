# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::CloudEventsFlowTriggerWorker, feature_category: :code_suggestions do
  let(:worker_class) do
    Class.new do
      def self.name
        'TestCloudEventsFlowTriggerWorker'
      end

      include Ai::CloudEventsFlowTriggerWorker

      def self.cloud_event_class
        MergeRequests::ApprovedCloudEvent
      end

      def self.event_type
        :merge_request
      end

      def self.action
        'approved'
      end
    end
  end

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
  let(:cloud_event) do
    MergeRequests::ApprovedCloudEvent.build(
      merge_request: merge_request,
      current_user: user,
      approval: instance_double(Approval, created_at: approved_at)
    )
  end

  let(:worker) { worker_class.new }
  let(:filter_evaluator) { instance_double(Ai::FlowTriggers::FilterEvaluator, allowed?: true) }
  let(:run_service) { instance_double(Ai::FlowTriggers::RunService) }

  describe '#handle_event' do
    subject(:handle_event) { worker.handle_event(cloud_event) }

    before do
      allow(worker).to receive_messages(find_resource_and_container: [merge_request, project], feature_enabled?: true)
      allow(Ai::FlowTriggers::FilterEvaluator).to receive(:new).and_return(filter_evaluator)
      allow(Ai::FlowTriggers::RunService).to receive(:new).and_return(run_service)
      allow(run_service).to receive(:execute)
    end

    context 'when all conditions are met' do
      it 'dispatches RunService' do
        expect(run_service).to receive(:execute)

        handle_event
      end
    end

    context 'when the cloud event class does not match' do
      let(:cloud_event) do
        MergeRequests::ApprovedEvent.new(
          data: { current_user_id: user.id, merge_request_id: merge_request.id, approved_at: approved_at.iso8601 }
        )
      end

      it 'returns early without calling RunService' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when find_resource_and_container returns nil' do
      before do
        allow(worker).to receive(:find_resource_and_container).and_return(nil)
      end

      it 'returns early without calling RunService' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the feature flag is disabled' do
      before do
        allow(worker).to receive(:feature_enabled?).and_return(false)
      end

      it 'returns early without calling RunService' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the user does not exist' do
      before do
        allow(cloud_event).to receive(:current_user).and_return(nil)
      end

      it 'returns early without calling RunService' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when passes_event_checks? returns false' do
      before do
        allow(worker).to receive(:passes_event_checks?).and_return(false)
      end

      it 'does not dispatch flow triggers' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'when the filter does not match' do
      let(:filter_evaluator) { instance_double(Ai::FlowTriggers::FilterEvaluator, allowed?: false) }

      it 'does not dispatch RunService' do
        expect(run_service).not_to receive(:execute)

        handle_event
      end
    end

    context 'with an action defined' do
      it 'passes action in filter data' do
        expect(Ai::FlowTriggers::FilterEvaluator).to receive(:new).with(
          flow_trigger: flow_trigger,
          hook_scope: :merge_request,
          data: { 'action' => 'approved' }
        ).and_return(filter_evaluator)

        handle_event
      end

      it 'passes action in execution params' do
        expect(run_service).to receive(:execute).with({
          input: merge_request.iid.to_s,
          event: :merge_request,
          action: 'approved'
        })

        handle_event
      end
    end

    context 'without an action defined' do
      let(:worker_class_without_action) do
        Class.new do
          def self.name
            'TestWorkerWithoutAction'
          end

          include Ai::CloudEventsFlowTriggerWorker

          def self.cloud_event_class
            MergeRequests::ApprovedCloudEvent
          end

          def self.event_type
            :merge_request_ready
          end
        end
      end

      let(:worker) { worker_class_without_action.new }

      let_it_be(:flow_trigger_ready) do
        create(:ai_flow_trigger,
          project: project,
          user: service_account,
          event_types: [Ai::FlowTrigger::EVENT_TYPES[:merge_request_ready]]
        )
      end

      before do
        allow(worker).to receive_messages(find_resource_and_container: [merge_request, project], feature_enabled?: true)
      end

      it 'passes empty filter data' do
        expect(Ai::FlowTriggers::FilterEvaluator).to receive(:new).with(
          flow_trigger: flow_trigger_ready,
          hook_scope: :merge_request_ready,
          data: {}
        ).and_return(filter_evaluator)

        handle_event
      end

      it 'does not include action in execution params' do
        expect(run_service).to receive(:execute).with({
          input: merge_request.iid.to_s,
          event: :merge_request_ready
        })

        handle_event
      end
    end

    context 'when RunService raises an error' do
      it 'tracks the exception and continues' do
        allow(run_service).to receive(:execute).and_raise(StandardError.new('boom'))

        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          hash_including(
            flow_trigger_id: flow_trigger.id,
            resource_id: merge_request.id,
            container_id: project.id
          )
        )

        handle_event
      end
    end
  end
end
