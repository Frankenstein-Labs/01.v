# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Messaging::Adapters::Base, feature_category: :duo_agent_platform do
  let_it_be(:project) { create(:project, :small_repo) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:service_account) { create(:user, :service_account) }

  let(:trigger_bundle) do
    described_class::TriggerBundle.new(
      current_user: current_user,
      service_account: service_account,
      flow_reference: 'developer/v1',
      project: project,
      goal: 'Fix CI pipeline'
    )
  end

  let(:callback_context) { { 'channel_id' => 'C123', 'thread_ts' => '1234.5678' } }

  let(:concrete_adapter_class) do
    Class.new(described_class) do
      attr_accessor :request_received, :flow_enqueued_args, :flow_failed_args

      def self.adapter_key
        'test_concrete'
      end

      def self.name
        'TestConcreteAdapter'
      end

      def initialize(ctx: nil)
        @ctx = ctx
        @request_received = false
        @flow_enqueued_args = nil
        @flow_failed_args = nil
      end

      def on_request_received
        @request_received = true
      end

      def on_flow_enqueued(callback_context:, workflow:)
        @flow_enqueued_args = { callback_context: callback_context, workflow: workflow }
      end

      def on_flow_failed(callback_context:, error:, workflow: nil)
        @flow_failed_args = { callback_context: callback_context, error: error, workflow: workflow }
      end

      def build_callback_context
        @ctx || {}
      end

      def deliver_result(callback_context:, message:, workflow:); end

      def deliver_error(callback_context:, error:); end
    end
  end

  describe '.from_callback_context' do
    it 'raises Gitlab::AbstractMethodError' do
      expect { described_class.from_callback_context({}) }.to raise_error(Gitlab::AbstractMethodError)
    end
  end

  describe '.adapter_key' do
    it 'raises Gitlab::AbstractMethodError' do
      expect { described_class.adapter_key }.to raise_error(Gitlab::AbstractMethodError)
    end
  end

  describe '.supports_live_progress?' do
    it 'defaults to false' do
      expect(described_class.supports_live_progress?).to be(false)
    end
  end

  describe '#on_progress' do
    it 'raises Gitlab::AbstractMethodError for adapters that have not implemented it' do
      delta = Ai::DuoWorkflows::ProgressReader::Delta.new(messages: [], new_messages: [], cursor: {})

      expect { concrete_adapter_class.new.on_progress(delta: delta, callback_context: {}) }
        .to raise_error(Gitlab::AbstractMethodError)
    end
  end

  describe '#trigger' do
    subject(:result) { adapter.trigger(trigger_bundle) }

    let(:adapter) { concrete_adapter_class.new(ctx: callback_context) }

    let(:workflow_double) { instance_double(::Ai::DuoWorkflows::Workflow) }
    let(:execute_result) { ServiceResponse.success(payload: { workflow: workflow_double }) }
    let(:member_result) { ServiceResponse.success }
    let(:member_service) { instance_double(::Ai::ServiceAccountMemberAddService, execute: member_result) }
    let(:workflow_service) { instance_double(::Ai::Catalog::ExecuteWorkflowService, execute: execute_result) }

    before do
      allow(::Ai::ServiceAccountMemberAddService).to receive(:new).and_return(member_service)
      allow(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).and_return(workflow_service)
    end

    it 'calls on_request_received before build_callback_context' do
      result
      expect(adapter.request_received).to be true
    end

    it 'returns the workflow execution result on success' do
      expect(result).to be_success
    end

    it 'calls on_flow_enqueued on success' do
      result
      expect(adapter.flow_enqueued_args).to include(workflow: workflow_double)
    end

    context 'when on_request_received raises (require_success {} short-circuits)' do
      let(:adapter) do
        klass = Class.new(concrete_adapter_class) do
          def on_request_received
            raise StandardError, 'acknowledgement failed'
          end
        end

        klass.new(ctx: callback_context)
      end

      it 'returns an error with reason :hook_failed' do
        expect(result).to be_error
        expect(result.reason).to eq(:hook_failed)
        expect(result.message).to eq('acknowledgement failed')
      end

      it 'tracks the exception' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)
        result
      end

      it 'does not call ExecuteWorkflowService' do
        expect(::Ai::Catalog::ExecuteWorkflowService).not_to receive(:new)
        result
      end
    end

    context 'when on_request_received returns ServiceResponse.error' do
      let(:adapter) do
        klass = Class.new(concrete_adapter_class) do
          def on_request_received
            ServiceResponse.error(message: 'not ready', reason: :precondition_failed)
          end
        end

        klass.new(ctx: callback_context)
      end

      it 'returns the error response' do
        expect(result).to be_error
        expect(result.reason).to eq(:precondition_failed)
        expect(result.message).to eq('not ready')
      end

      it 'does not track an exception' do
        expect(::Gitlab::ErrorTracking).not_to receive(:track_exception)
        result
      end

      it 'does not call ExecuteWorkflowService' do
        expect(::Ai::Catalog::ExecuteWorkflowService).not_to receive(:new)
        result
      end
    end

    context 'when ServiceAccountMemberAddService fails' do
      let(:member_result) { ServiceResponse.error(message: 'Failed to add SA') }

      it 'returns a service_account_error' do
        expect(result).to be_error
        expect(result.reason).to eq(:service_account_error)
      end

      it 'calls on_flow_failed with workflow: nil' do
        result
        expect(adapter.flow_failed_args).to include(error: :service_account_error, workflow: nil)
      end
    end

    context 'when ExecuteWorkflowService fails' do
      let(:execute_result) { ServiceResponse.error(message: 'workflow creation failed') }

      it 'returns the error result' do
        expect(result).to be_error
      end

      it 'calls on_flow_failed with workflow: nil' do
        result
        expect(adapter.flow_failed_args).to include(error: :execute_workflow_failed, workflow: nil)
      end
    end

    context 'when on_flow_enqueued raises' do
      let(:adapter) do
        klass = Class.new(concrete_adapter_class) do
          def on_flow_enqueued(**)
            raise StandardError, 'flow enqueued notification failed'
          end
        end

        klass.new(ctx: callback_context)
      end

      it 'still returns success (handle_error {} swallows)' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)
        expect(result).to be_success
      end
    end

    context 'when on_flow_failed raises during SA failure' do
      let(:member_result) { ServiceResponse.error(message: 'Failed to add SA') }

      let(:adapter) do
        klass = Class.new(concrete_adapter_class) do
          def on_flow_failed(**)
            raise StandardError, 'notification failed'
          end
        end

        klass.new(ctx: callback_context)
      end

      it 'still returns the service_account_error (handle_error {} swallows hook error)' do
        expect(::Gitlab::ErrorTracking).to receive(:track_exception)
        expect(result).to be_error
        expect(result.reason).to eq(:service_account_error)
      end
    end

    describe 'resource_params translation' do
      context 'when resource is an Issue' do
        let(:issue) { create(:issue, project: project) }
        let(:trigger_bundle) do
          described_class::TriggerBundle.new(
            current_user: current_user,
            service_account: service_account,
            flow_reference: 'developer/v1',
            project: project,
            goal: 'Fix issue',
            resource: issue
          )
        end

        it 'passes issue_id to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(issue_id: issue.iid)
          ).and_return(workflow_service)

          result
        end
      end

      context 'when resource is a MergeRequest' do
        let(:merge_request) { create(:merge_request, source_project: project) }
        let(:trigger_bundle) do
          described_class::TriggerBundle.new(
            current_user: current_user,
            service_account: service_account,
            flow_reference: 'developer/v1',
            project: project,
            goal: 'Review MR',
            resource: merge_request
          )
        end

        it 'passes merge_request_id to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(merge_request_id: merge_request.iid)
          ).and_return(workflow_service)

          result
        end
      end

      context 'when resource is nil' do
        it 'passes no resource params to ExecuteWorkflowService' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_not_including(:issue_id, :merge_request_id)
          ).and_return(workflow_service)

          result
        end
      end
    end

    describe 'enriched_callback_context' do
      it 'injects adapter key, service_account_id, and flow_reference into callback context' do
        expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
          current_user,
          hash_including(
            messaging_callback_context: hash_including(
              'adapter' => 'test_concrete',
              'service_account_id' => service_account.id,
              'flow_reference' => 'developer/v1'
            )
          )
        ).and_return(workflow_service)

        result
      end

      it 'compacts nil values from the context' do
        expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
          current_user,
          hash_including(
            messaging_callback_context: hash_not_including('item_version', 'flow_config_id')
          )
        ).and_return(workflow_service)

        result
      end

      context 'when flow versioning fields are provided' do
        let(:trigger_bundle) do
          described_class::TriggerBundle.new(
            current_user: current_user,
            service_account: service_account,
            flow_reference: 'developer/v1',
            flow_config_id: 'developer',
            flow_config_schema_version: 'v1',
            flow_version: '2.0.0',
            project: project,
            goal: 'Fix CI pipeline'
          )
        end

        it 'includes flow versioning fields in the callback context' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(
              messaging_callback_context: hash_including(
                'flow_config_id' => 'developer',
                'flow_config_schema_version' => 'v1',
                'flow_version' => '2.0.0'
              )
            )
          ).and_return(workflow_service)

          result
        end
      end
    end

    describe 'source_branch fallback' do
      context 'when source_branch is nil' do
        it 'falls back to project default branch' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(source_branch: project.default_branch_or_main)
          ).and_return(workflow_service)

          result
        end
      end

      context 'when source_branch is provided' do
        let(:trigger_bundle) do
          described_class::TriggerBundle.new(
            current_user: current_user,
            service_account: service_account,
            flow_reference: 'developer/v1',
            project: project,
            goal: 'Fix CI pipeline',
            source_branch: 'custom-branch'
          )
        end

        it 'uses the provided source_branch' do
          expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
            current_user,
            hash_including(source_branch: 'custom-branch')
          ).and_return(workflow_service)

          result
        end
      end
    end

    describe 'flow versioning pass-through' do
      let(:trigger_bundle) do
        described_class::TriggerBundle.new(
          current_user: current_user,
          service_account: service_account,
          flow_reference: 'developer/v1',
          flow_config_id: 'developer',
          flow_config_schema_version: 'v1',
          flow_version: '2.0.0',
          project: project,
          goal: 'Fix CI pipeline'
        )
      end

      it 'passes flow versioning fields to ExecuteWorkflowService' do
        expect(::Ai::Catalog::ExecuteWorkflowService).to receive(:new).with(
          current_user,
          hash_including(
            flow_config_id: 'developer',
            flow_config_schema_version: 'v1',
            flow_version: '2.0.0'
          )
        ).and_return(workflow_service)

        result
      end
    end

    describe 'composite identity linking' do
      # Use let (not let_it_be) for state mutated via update! and stub_feature_flags.
      let(:service_account) { create(:user, :service_account) }
      let(:oauth_app) { create(:oauth_application, name: 'Duo Workflow', scopes: %w[ai_workflows mcp user:*]) }

      before do
        service_account.update!(composite_identity_enforced: true)
        ::Ai::Setting.for_organization(project.organization).update!(duo_workflow_oauth_application: oauth_app)
      end

      it 'calls link_from_web_request' do
        expect(::Gitlab::Auth::Identity).to receive(:link_from_web_request).with(
          service_account: service_account,
          scoped_user: current_user
        )

        result
      end

      context 'when oauth application is not configured' do
        before do
          ::Ai::Setting.for_organization(project.organization).update!(duo_workflow_oauth_application: nil)
        end

        it 'does not call link_from_web_request' do
          expect(::Gitlab::Auth::Identity).not_to receive(:link_from_web_request)
          result
        end
      end

      context 'when organization-scoped AI settings are enabled' do
        let(:organization_oauth_app) do
          create(:oauth_application, name: 'Duo Workflow Org', scopes: %w[ai_workflows mcp user:*])
        end

        before do
          ::Ai::Setting.for_organization(project.organization).update!(duo_workflow_oauth_application: nil)
          ::Ai::Setting.for_organization(project.organization).update!(
            duo_workflow_oauth_application: organization_oauth_app
          )
        end

        it 'calls link_from_web_request' do
          expect(::Gitlab::Auth::Identity).to receive(:link_from_web_request).with(
            service_account: service_account,
            scoped_user: current_user
          )

          result
        end
      end

      context 'when SA does not enforce composite identity' do
        before do
          service_account.update!(composite_identity_enforced: false)
        end

        it 'does not call link_from_web_request' do
          expect(::Gitlab::Auth::Identity).not_to receive(:link_from_web_request)
          result
        end
      end
    end
  end

  describe '#with_lifecycle_hooks' do
    let(:adapter) { concrete_adapter_class.new(ctx: callback_context) }
    let(:workflow_double) { instance_double(::Ai::DuoWorkflows::Workflow) }

    context 'when the block succeeds' do
      it 'runs on_request_received and yields the built callback context' do
        yielded = nil
        adapter.with_lifecycle_hooks do |ctx|
          yielded = ctx
          [ServiceResponse.success, workflow_double]
        end

        expect(adapter.request_received).to be true
        expect(yielded).to eq(callback_context)
      end

      it 'dispatches on_flow_enqueued with the yielded workflow and returns the response' do
        result = adapter.with_lifecycle_hooks { |_ctx| [ServiceResponse.success, workflow_double] }

        expect(result).to be_success
        expect(adapter.flow_enqueued_args).to eq(callback_context: callback_context, workflow: workflow_double)
        expect(adapter.flow_failed_args).to be_nil
      end
    end

    context 'when the block fails' do
      it 'dispatches on_flow_failed with :execute_workflow_failed when the response carries no reason' do
        result = adapter.with_lifecycle_hooks { |_ctx| [ServiceResponse.error(message: 'boom'), nil] }

        expect(result).to be_error
        expect(adapter.flow_failed_args).to eq(
          callback_context: callback_context, error: :execute_workflow_failed, workflow: nil
        )
      end

      it 'uses the response reason when present' do
        adapter.with_lifecycle_hooks do |_ctx|
          [ServiceResponse.error(message: 'x', reason: :service_account_error), nil]
        end

        expect(adapter.flow_failed_args).to include(error: :service_account_error)
      end

      it 'still delivers a failure when the block returns a workflow (no silent limbo)' do
        adapter.with_lifecycle_hooks { |_ctx| [ServiceResponse.error(message: 'x'), workflow_double] }

        expect(adapter.flow_enqueued_args).to be_nil
        expect(adapter.flow_failed_args).to include(error: :execute_workflow_failed, workflow: nil)
      end
    end

    context 'when on_request_received returns an error' do
      before do
        allow(adapter).to receive(:on_request_received).and_return(ServiceResponse.error(message: 'nope'))
      end

      it 'short-circuits without yielding or dispatching' do
        block_called = false
        result = adapter.with_lifecycle_hooks do |_ctx|
          block_called = true
          [ServiceResponse.success, workflow_double]
        end

        expect(result).to be_error
        expect(block_called).to be false
        expect(adapter.flow_enqueued_args).to be_nil
        expect(adapter.flow_failed_args).to be_nil
      end
    end
  end

  describe 'TriggerBundle' do
    it 'raises ArgumentError on unknown keys' do
      expect do
        described_class::TriggerBundle.new(
          current_user: current_user,
          service_account: service_account,
          flow_reference: 'developer/v1',
          project: project,
          goal: 'goal',
          bogus_key: 'nope'
        )
      end.to raise_error(ArgumentError)
    end

    it 'raises ArgumentError when required fields are missing' do
      expect do
        described_class::TriggerBundle.new(
          current_user: current_user,
          service_account: service_account
        )
      end.to raise_error(ArgumentError)
    end

    it 'defaults optional fields to nil' do
      bundle = described_class::TriggerBundle.new(
        current_user: current_user,
        service_account: service_account,
        flow_reference: 'developer/v1',
        project: project,
        goal: 'goal'
      )

      expect(bundle.item_version).to be_nil
      expect(bundle.resource).to be_nil
      expect(bundle.additional_context).to be_nil
      expect(bundle.source_branch).to be_nil
      expect(bundle.flow_config_id).to be_nil
      expect(bundle.flow_config_schema_version).to be_nil
      expect(bundle.flow_version).to be_nil
    end

    it 'accepts flow versioning fields' do
      bundle = described_class::TriggerBundle.new(
        current_user: current_user,
        service_account: service_account,
        flow_reference: 'developer/v1',
        flow_config_id: 'developer',
        flow_config_schema_version: 'v1',
        flow_version: '2.0.0',
        project: project,
        goal: 'goal'
      )

      expect(bundle.flow_config_id).to eq('developer')
      expect(bundle.flow_config_schema_version).to eq('v1')
      expect(bundle.flow_version).to eq('2.0.0')
    end
  end

  describe '#on_flow_failed' do
    subject(:adapter) { concrete_adapter_class.new }

    context 'when called from sync path (workflow: nil)' do
      it 'receives workflow: nil' do
        adapter.on_flow_failed(callback_context: {}, error: :test_error, workflow: nil)

        expect(adapter.flow_failed_args).to include(workflow: nil)
      end
    end

    context 'when called from async path (workflow: present)' do
      let(:workflow) { instance_double(::Ai::DuoWorkflows::Workflow) }

      it 'receives the workflow object' do
        adapter.on_flow_failed(callback_context: {}, error: :flow_failed, workflow: workflow)

        expect(adapter.flow_failed_args).to include(workflow: workflow)
      end
    end
  end

  describe 'default lifecycle hooks' do
    subject(:adapter) { described_class.new }

    describe '#on_request_received' do
      it 'is a no-op by default' do
        expect(adapter.on_request_received).to be_nil
      end
    end

    describe '#on_flow_enqueued' do
      it 'is a no-op by default' do
        expect(adapter.on_flow_enqueued(callback_context: {}, workflow: nil)).to be_nil
      end
    end

    describe '#on_flow_started' do
      it 'is a no-op by default' do
        expect(adapter.on_flow_started(callback_context: {}, workflow: nil)).to be_nil
      end
    end

    describe '#on_flow_completed' do
      it 'is a no-op by default' do
        expect(adapter.on_flow_completed(callback_context: {}, workflow: nil)).to be_nil
      end
    end

    describe '#on_flow_failed' do
      it 'delegates to deliver_error' do
        expect(adapter).to receive(:deliver_error).with(callback_context: {}, error: :test)
        adapter.on_flow_failed(callback_context: {}, error: :test)
      end
    end
  end
end
