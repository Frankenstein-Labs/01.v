# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CleanStuckWorkflowsService, feature_category: :duo_agent_platform do
  subject(:execute) { described_class.new.execute }

  describe '#execute' do
    using RSpec::Parameterized::TableSyntax

    where(:updated_when, :current_status, :expected_status) do
      "recent" | :created                      | :created
      "recent" | :running                      | :running
      "recent" | :paused                       | :paused
      "recent" | :finished                     | :finished
      "recent" | :failed                       | :failed
      "recent" | :stopped                      | :stopped
      "recent" | :input_required               | :input_required
      "recent" | :plan_approval_required       | :plan_approval_required
      "recent" | :tool_call_approval_required  | :tool_call_approval_required
      "old"    | :created                      | :failed
      "old"    | :running                      | :failed
      "old"    | :paused                       | :paused
      "old"    | :finished                     | :finished
      "old"    | :failed                       | :failed
      "old"    | :stopped                      | :stopped
      "old"    | :input_required               | :input_required
      "old"    | :plan_approval_required       | :plan_approval_required
      "old"    | :tool_call_approval_required  | :tool_call_approval_required
    end

    with_them do
      action = params[:current_status] == params[:expected_status] ? "keeps" : "changes"
      test_case_name = "#{action} #{params[:updated_when]} workflow status: " \
        "#{params[:current_status]} \u2192 #{params[:expected_status]}"
      it test_case_name do
        updated_at = updated_when == "old" ? 2.days.ago : 1.minute.ago
        workflow = create(:duo_workflows_workflow, status: status_enum(current_status), updated_at: updated_at)
        expect(workflow.reload.status).to eq(status_enum(current_status))

        if current_status != expected_status
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: "duo_session_failed",
              author: an_instance_of(::Gitlab::Audit::UnauthenticatedAuthor).and(having_attributes(name: '(System)')),
              scope: workflow.project,
              target: workflow,
              message: "Duo session failed: stuck session cleaned up after timeout"
            )
          ).and_call_original

          expect { execute }.to trigger_internal_events("cleanup_stuck_agent_platform_session")
                                  .with(category: "Ai::DuoWorkflows::CleanStuckWorkflowsService",
                                    user: workflow.user,
                                    project: workflow.project,
                                    additional_properties: {
                                      label: workflow.workflow_definition,
                                      value: workflow.id,
                                      property: "failed"
                                    })
        end

        expect(workflow.reload.status).to eq(status_enum(expected_status))
      end
    end

    context 'when the workflow fails to drop' do
      it 'does not track events for a workflow that was not dropped' do
        workflow = create(:duo_workflows_workflow, :running, updated_at: 2.days.ago)

        allow_next_found_instance_of(Ai::DuoWorkflows::Workflow) do |instance|
          allow(instance).to receive(:drop).and_return(false)
        end

        expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

        expect { execute }.not_to trigger_internal_events("cleanup_stuck_agent_platform_session")

        expect(workflow.reload.status).to eq(status_enum(:running))
      end
    end

    context 'with a namespace-level workflow' do
      let_it_be_with_reload(:workflow) do
        create(:duo_workflows_workflow, :running, namespace: create(:group), updated_at: 2.days.ago)
      end

      it 'emits the internal event scoped to the namespace' do
        expect { execute }.to trigger_internal_events("cleanup_stuck_agent_platform_session")
                        .with(category: "Ai::DuoWorkflows::CleanStuckWorkflowsService",
                          user: workflow.user,
                          project: nil,
                          namespace: workflow.namespace,
                          additional_properties: {
                            label: workflow.workflow_definition,
                            value: workflow.id,
                            property: "failed"
                          })
      end

      it 'emits the audit event scoped to the namespace' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(name: "duo_session_failed", scope: workflow.namespace)
        ).and_call_original

        execute

        expect(workflow.reload.status).to eq(status_enum(:failed))
      end
    end
  end

  describe 'Prometheus counter', :prometheus do
    let(:counter) { described_class::STUCK_WORKFLOWS_COUNTER }

    it 'increments the stuck workflows counter with the original status and flow type labels' do
      create(:duo_workflows_workflow, status: status_enum(:created), updated_at: 2.days.ago)
      create(:duo_workflows_workflow, status: status_enum(:created), updated_at: 2.days.ago)
      create(:duo_workflows_workflow, status: status_enum(:running), updated_at: 2.days.ago)

      expect { execute }
        .to change { counter.get(status: 'created', flow_type: 'software_development') }.by(2)
        .and change { counter.get(status: 'running', flow_type: 'software_development') }.by(1)
    end

    it 'counts each flow type separately' do
      create(:duo_workflows_workflow, :agentic_chat, status: status_enum(:running), updated_at: 2.days.ago)
      create(:duo_workflows_workflow, status: status_enum(:running), updated_at: 2.days.ago)

      expect { execute }
        .to change { counter.get(status: 'running', flow_type: 'chat') }.by(1)
        .and change { counter.get(status: 'running', flow_type: 'software_development') }.by(1)
    end

    it 'does not increment the counter for recent workflows' do
      create(:duo_workflows_workflow, status: status_enum(:created), updated_at: 1.minute.ago)

      expect { execute }.not_to change { counter.get(status: 'created', flow_type: 'software_development') }
    end

    it 'does not increment the counter when the workflow fails to drop' do
      create(:duo_workflows_workflow, :running, updated_at: 2.days.ago)

      allow_next_found_instance_of(Ai::DuoWorkflows::Workflow) do |instance|
        allow(instance).to receive(:drop).and_return(false)
      end

      expect { execute }.not_to change { counter.get(status: 'running', flow_type: 'software_development') }
    end
  end

  def status_enum(status)
    Ai::DuoWorkflows::Workflow.state_machine.states[status].value
  end
end
