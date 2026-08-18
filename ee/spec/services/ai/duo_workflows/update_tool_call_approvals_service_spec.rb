# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::UpdateToolCallApprovalsService, feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:result) do
      described_class.new(
        workflow: workflow,
        tool_name: tool_name,
        tool_call_args: tool_call_args,
        current_user: user,
        **extra_params
      ).execute
    end

    let_it_be_with_reload(:group) { create(:group) }
    let_it_be_with_reload(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user, maintainer_of: project) }

    let(:workflow) { create(:duo_workflows_workflow, project: project, user: user) }
    let(:tool_name) { 'run_command' }
    let(:tool_call_args) { '{"command": "ls -la", "working_dir": "/home"}' }
    let(:extra_params) { {} }

    context 'when both tool_call_args and pattern are provided' do
      let(:extra_params) { { pattern: '*npm*' } }

      it 'returns error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Exactly one of tool_call_args or pattern must be provided')
      end
    end

    context 'when neither tool_call_args nor pattern is provided' do
      let(:tool_call_args) { nil }

      it 'returns error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Exactly one of tool_call_args or pattern must be provided')
      end
    end

    context 'when user does not have permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(false)
      end

      it 'returns unauthorized error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Can not update workflow')
        expect(result.reason).to eq(:unauthorized)
        expect(workflow.reload.tool_call_approvals).to eq({})
      end
    end

    context 'when user has permission to update workflow but tool approval is not enabled' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
        group.namespace_settings.update!(tool_approval_for_session_enabled: false)
      end

      it 'returns forbidden error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Tool approval for session is not enabled for this namespace')
        expect(result.reason).to eq(:forbidden)
      end
    end

    context 'when workflow has no resource parent' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
        allow(workflow).to receive_messages(project: nil, namespace: nil)
      end

      it 'returns forbidden error', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Tool approval for session is not enabled for this namespace')
        expect(result.reason).to eq(:forbidden)
      end
    end

    context 'when workflow project has no namespace but workflow has a namespace' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
        allow(workflow).to receive_messages(project: nil, namespace: group)
        group.namespace_settings.update!(tool_approval_for_session_enabled: true)
      end

      it 'falls back to workflow namespace and succeeds', :aggregate_failures do
        expect(result.success?).to be true
      end
    end

    context 'when workflow is in a subgroup with setting disabled' do
      let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
      let_it_be(:subgroup_project) { create(:project, group: subgroup) }

      let(:workflow) { create(:duo_workflows_workflow, project: subgroup_project, user: user) }

      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
        group.namespace_settings.update!(tool_approval_for_session_enabled: true)
        subgroup.namespace_settings.update!(tool_approval_for_session_enabled: false)
      end

      it 'returns forbidden error because subgroup overrides root', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Tool approval for session is not enabled for this namespace')
        expect(result.reason).to eq(:forbidden)
      end
    end

    context 'when workflow is in a subgroup inheriting from root with root OFF' do
      let_it_be_with_reload(:subgroup) { create(:group, parent: group) }
      let_it_be(:subgroup_project) { create(:project, group: subgroup) }

      let(:workflow) { create(:duo_workflows_workflow, project: subgroup_project, user: user) }

      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
        group.namespace_settings.update!(tool_approval_for_session_enabled: false)
      end

      it 'returns forbidden error because root is OFF and subgroup inherits', :aggregate_failures do
        expect(result.error?).to be true
        expect(result.message).to eq('Tool approval for session is not enabled for this namespace')
        expect(result.reason).to eq(:forbidden)
      end
    end

    context 'when user has permission to update workflow' do
      before do
        allow(user).to receive(:can?).with(:update_duo_workflow, workflow).and_return(true)
        group.namespace_settings.update!(tool_approval_for_session_enabled: true)
        project.project_setting.update!(tool_approval_for_session_enabled: true)
      end

      it 'acquires a lock and saves workflow', :aggregate_failures do
        expect(workflow).to receive(:with_lock).with('FOR UPDATE NOWAIT').and_yield
        expect(workflow).to receive(:add_tool_call_approval).with(tool_name: tool_name, call_args: tool_call_args)
        expect(workflow).to receive(:save).and_return(true)

        expect(result.success?).to be true
        expect(result.message).to eq('Tool call approvals updated successfully')
        expect(result.payload[:workflow]).to eq(workflow)
      end

      it 'emits a duo_tool_call_approved audit event' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'duo_tool_call_approved',
            author: user,
            scope: project,
            target: workflow,
            message: "Approved tool call: #{tool_name}"
          )
        )

        result
      end

      context 'when audit logging raises an exception' do
        before do
          allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(StandardError, 'audit failure')
        end

        it 'tracks the exception and still returns success', :aggregate_failures do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(
            an_instance_of(StandardError),
            workflow_id: workflow.id
          )

          expect(result.success?).to be true
          expect(result.message).to eq('Tool call approvals updated successfully')
        end
      end

      context 'when workflow save fails' do
        let(:errors) { ActiveModel::Errors.new(workflow) }

        before do
          errors.add(:base, 'Validation failed')
          allow(workflow).to receive(:with_lock).with('FOR UPDATE NOWAIT').and_yield
          allow(workflow).to receive(:add_tool_call_approval)
          allow(workflow).to receive_messages(save: false, errors: errors)
        end

        it 'returns error with validation messages', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to include('Failed to update tool_call_approvals')
          expect(result.message).to include('Validation failed')
        end

        it 'does not emit an audit event' do
          expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

          result
        end
      end

      context 'when approval_source is provided' do
        let(:extra_params) { { approval_source: 'user_explicit' } }

        it 'includes approval_source in the audit event additional_details' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_tool_call_approved',
              additional_details: { approval_source: 'user_explicit' }
            )
          )

          result
        end
      end

      context 'when approval_source is not provided' do
        it 'omits approval_source from the audit event additional_details' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_tool_call_approved',
              additional_details: {}
            )
          )

          result
        end
      end

      context 'when pattern is provided' do
        let(:tool_call_args) { nil }
        let(:extra_params) { { pattern: '*npm*' } }

        it 'calls add_tool_call_pattern_approval', :aggregate_failures do
          expect(workflow).to receive(:with_lock).with('FOR UPDATE NOWAIT').and_yield
          expect(workflow).to receive(:add_tool_call_pattern_approval).with(
            tool_name: tool_name, pattern: '*npm*'
          )
          expect(workflow).to receive(:save).and_return(true)

          expect(result.success?).to be true
          expect(result.message).to eq('Tool call approvals updated successfully')
        end

        it 'includes pattern in audit event message' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_tool_call_approved',
              message: "Approved tool call: #{tool_name} with pattern: *npm*"
            )
          )

          result
        end
      end

      context 'when pattern validation fails' do
        let(:tool_call_args) { nil }
        let(:extra_params) { { pattern: '' } }

        it 'returns error with validation message', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to eq('Pattern must be a non-empty string')
        end
      end

      context 'when workflow is locked by another process' do
        before do
          allow(workflow).to receive(:with_lock).with('FOR UPDATE NOWAIT')
            .and_raise(ActiveRecord::LockWaitTimeout)
        end

        it 'returns error indicating concurrent update', :aggregate_failures do
          expect(result.error?).to be true
          expect(result.message).to eq('Workflow is currently being updated, please try again')
        end
      end
    end
  end
end
