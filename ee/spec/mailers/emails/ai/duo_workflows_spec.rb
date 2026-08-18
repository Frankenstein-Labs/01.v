# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Emails::Ai::DuoWorkflows, feature_category: :duo_agent_platform do
  include EmailSpec::Matchers

  let(:group) { build_stubbed(:group) }
  let(:project) { build_stubbed(:project, group: group) }
  let(:user) { build_stubbed(:user) }
  let(:workflow) do
    build_stubbed(
      :duo_workflows_workflow,
      project: project,
      user: user,
      goal: "Fix the failing pipeline and open an MR",
      workflow_definition: "software_developer"
    )
  end

  describe '#duo_workflow_input_required_email' do
    subject(:email) { Notify.duo_workflow_input_required_email(user.id, workflow.id) }

    let(:ui_chat_log) { [{ 'message_type' => 'request', 'content' => 'Working...' }] }

    before do
      allow(::Ai::DuoWorkflows::Workflow).to receive(:find_by_id).with(workflow.id).and_return(workflow)
      allow(User).to receive(:find_by_id).with(user.id).and_return(user)
      allow(user).to receive(:notification_email_for).and_return(user.email)
      allow(workflow).to receive(:latest_ui_chat_log).and_return(ui_chat_log.is_a?(Array) ? ui_chat_log : [])
    end

    it 'sends mail with expected contents', :aggregate_failures do
      expect(email).to have_subject(/Your Duo session needs your input/)
      expect(email).to be_delivered_to([user.email])
      expect(email).to have_body_text(workflow.goal)
      expect(email).to have_body_text(workflow.workflow_definition)
      expect(email).to have_body_text(workflow.web_url)
      expect(email).to have_body_text(project.full_name)
    end

    context 'with checkpoint request message' do
      where(:description, :ui_chat_log, :expected_body, :excluded_body) do
        [
          [
            'single request message',
            [
              { 'message_type' => 'agent', 'content' => 'Analyzing the codebase...' },
              { 'message_type' => 'request', 'content' => 'Please review the plan and approve to continue.' },
              { 'message_type' => 'tool', 'content' => 'read_file result' }
            ],
            'Please review the plan and approve to continue.',
            nil
          ],
          [
            'multiple request messages (picks last)',
            [
              { 'message_type' => 'request', 'content' => 'First approval request' },
              { 'message_type' => 'agent', 'content' => 'Working...' },
              { 'message_type' => 'request', 'content' => 'Second approval request' }
            ],
            'Second approval request',
            'First approval request'
          ]
        ]
      end

      with_them do
        it "includes the pending action for #{description}" do
          expect(email).to have_body_text(expected_body)
          expect(email).not_to have_body_text(excluded_body) if excluded_body
        end
      end
    end

    context 'without a pending action' do
      where(:description, :ui_chat_log) do
        [
          ['no request message', [{ 'message_type' => 'agent', 'content' => 'Working...' }]],
          ['no checkpoints', nil]
        ]
      end

      with_them do
        it "omits pending action when #{description}" do
          expect(email).to be_delivered_to([user.email])
          expect(email).not_to have_body_text(s_('DuoWorkflow|Pending action:'))
        end
      end
    end

    context 'when there is no checkpoint' do
      before do
        allow(workflow).to receive(:latest_ui_chat_log).and_return([])
      end

      it 'still renders and omits the pending action', :aggregate_failures do
        expect(email).to be_delivered_to([user.email])
        expect(email).not_to have_body_text(s_('DuoWorkflow|Pending action:'))
      end
    end

    context 'when the workflow does not exist' do
      before do
        allow(::Ai::DuoWorkflows::Workflow).to receive(:find_by_id).with(non_existing_record_id).and_return(nil)
      end

      subject(:email) { Notify.duo_workflow_input_required_email(user.id, non_existing_record_id) }

      it 'does not send an email' do
        expect(email.to).to be_blank
      end
    end

    context 'when the recipient does not exist' do
      before do
        allow(User).to receive(:find_by_id).with(non_existing_record_id).and_return(nil)
      end

      subject(:email) { Notify.duo_workflow_input_required_email(non_existing_record_id, workflow.id) }

      it 'does not send an email' do
        expect(email.to).to be_blank
      end
    end

    context 'when the workflow has no project (namespace-level flow)' do
      let(:namespace_workflow) do
        build_stubbed(:duo_workflows_workflow, project: nil, namespace: group, user: user, goal: "Namespace goal")
      end

      subject(:email) { Notify.duo_workflow_input_required_email(user.id, namespace_workflow.id) }

      before do
        allow(::Ai::DuoWorkflows::Workflow).to receive(:find_by_id).with(namespace_workflow.id)
          .and_return(namespace_workflow)
        allow(namespace_workflow).to receive(:latest_ui_chat_log).and_return(ui_chat_log)
      end

      it 'still renders and is delivered to the user default notification email' do
        expect(email).to have_subject(/Your Duo session needs your input/)
        expect(email).to be_delivered_to([user.email])
      end
    end
  end
end
