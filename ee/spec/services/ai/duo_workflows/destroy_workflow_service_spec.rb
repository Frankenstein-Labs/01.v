# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::DestroyWorkflowService, feature_category: :duo_agent_platform do
  describe '#execute' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:workflow) { create(:duo_workflows_workflow, :agentic_chat, project: project, user: user) }

    subject(:execute) do
      described_class
        .new(workflow: workflow, current_user: user)
        .execute
    end

    it 'destroys a workflow' do
      expect { execute }.to change { Ai::DuoWorkflows::Workflow.count }.by(-1)
    end

    it 'emits a duo_session_deleted audit event' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
        hash_including(
          name: 'duo_session_deleted',
          author: user,
          scope: project,
          target: workflow,
          target_details: "#{workflow.workflow_definition} session #{workflow.id}",
          message: 'Deleted Duo session'
        )
      )

      execute
    end

    context 'when auditing raises an error' do
      let(:audit_error) { StandardError.new('audit failure') }

      before do
        allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(audit_error)

        execute
      end

      it 'still returns success' do
        allow(Gitlab::ErrorTracking).to receive(:track_exception)

        expect(execute).to be_success
      end
    end

    context 'when user can not destroy workflow' do
      let_it_be(:other_user) { create(:user) }

      subject(:execute) do
        described_class
          .new(workflow: workflow, current_user: other_user)
          .execute
      end

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to include('User not authorized to delete workflow')
      end
    end

    context 'when the workflow cannot be destroyed' do
      before do
        allow(workflow).to receive(:destroy).and_return(false)
        workflow.errors.add(:base, "Something bad")
      end

      it 'returns an error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to include('Something bad')
      end

      it 'does not emit an audit event' do
        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        execute
      end
    end

    context 'when workflow is not a chat workflow' do
      let_it_be(:non_chat_workflow) { create(:duo_workflows_workflow, project: project, user: user) }

      subject(:execute) do
        described_class
          .new(workflow: non_chat_workflow, current_user: user)
          .execute
      end

      it 'returns an authorization error' do
        expect(execute[:status]).to eq(:error)
        expect(execute[:message]).to include('User not authorized to delete workflow')
      end
    end
  end
end
