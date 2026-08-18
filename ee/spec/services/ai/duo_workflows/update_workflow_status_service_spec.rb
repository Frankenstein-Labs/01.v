# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::UpdateWorkflowStatusService, feature_category: :duo_agent_platform do
  describe '#execute' do
    subject(:result) { described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute }

    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:user) { create(:user, maintainer_of: project) }
    let_it_be(:another_user) { create(:user) }
    let(:workflow_initial_status_enum) { 1 }

    let(:duo_workflow) do
      create(:duo_workflows_workflow, project: project, user: user, status: workflow_initial_status_enum)
    end

    let(:chat_workflow) do
      create(:duo_workflows_workflow, :agentic_chat, project: project, user: user, status: workflow_initial_status_enum)
    end

    let(:workflow) { duo_workflow }

    context "when duo workflow is not available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
      end

      it "returns not found", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not update workflow")
        expect(result[:reason]).to eq(:unauthorized)
        expect(workflow.reload.human_status_name).to eq("running")
      end
    end

    context "when duo workflow is available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
        allow(user).to receive(:allowed_to_use?).and_return(true)
      end

      it "can finish a workflow", :aggregate_failures do
        time = 3.days.ago
        ts = time.change(nsec: (time.nsec / 1000) * 1000)
        checkpoint = create(:duo_workflows_checkpoint, workflow: workflow, created_at: ts, project: workflow.project)
        expect(GraphqlTriggers).to receive(:workflow_events_updated).with(checkpoint).and_return(1)

        expect do
          result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute
          expect(result[:status]).to eq(:success)
          expect(result[:message]).to eq("Workflow status updated")
        end.to trigger_internal_events("agent_platform_session_finished")
                           .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                             user: workflow.user,
                             project: workflow.project,
                             additional_properties: {
                               label: workflow.workflow_definition,
                               value: workflow.id,
                               property: "ide"
                             })

        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it 'creates an audit event when finishing a workflow' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'duo_session_finished',
            author: user,
            scope: project,
            target: workflow,
            message: 'Completed Duo session'
          )
        )

        described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute
      end

      context 'when audit event creation fails for finish event' do
        let(:audit_error) { StandardError.new('Audit service unavailable') }

        before do
          allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
        end

        it 'tracks the exception and workflow update continues successfully' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            audit_error,
            hash_including(workflow_id: workflow.id)
          )

          result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

          expect(result[:status]).to eq(:success)
          expect(workflow.reload.human_status_name).to eq("finished")
        end
      end

      it "sets summary when dropping a workflow with a summary", :aggregate_failures do
        result = described_class.new(
          workflow: workflow, current_user: user, status_event: "drop", summary: "Error during Session: script_failure"
        ).execute

        expect(result[:status]).to eq(:success)
        expect(workflow.reload.summary).to eq("Error during Session: script_failure")
        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it "can drop a workflow", :aggregate_failures do
        expect do
          result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

          expect(result[:status]).to eq(:success)
          expect(result[:message]).to eq("Workflow status updated")
        end.to trigger_internal_events("agent_platform_session_dropped")
                             .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                               user: workflow.user,
                               project: workflow.project,
                               additional_properties: {
                                 label: workflow.workflow_definition,
                                 value: workflow.id,
                                 property: "ide"
                               })

        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it 'creates an audit event when dropping a workflow' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(
            name: 'duo_session_failed',
            author: user,
            scope: project,
            target: workflow,
            message: 'Duo session failed'
          )
        )

        described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute
      end

      context 'when audit event creation fails for drop event' do
        let(:audit_error) { StandardError.new('Audit service unavailable') }

        before do
          allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
        end

        it 'tracks the exception and workflow update continues successfully' do
          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            audit_error,
            hash_including(workflow_id: workflow.id)
          )

          result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

          expect(result[:status]).to eq(:success)
          expect(workflow.reload.human_status_name).to eq("failed")
        end
      end

      it "can pause a workflow", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "pause").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow status updated")
        expect(workflow.reload.human_status_name).to eq("paused")
      end

      context "when workflow is not from a pipeline" do
        before do
          allow(workflow).to receive(:from_pipeline?).and_return(false)
        end

        it "does not send any notifications on require_input" do
          expect(::Notify).not_to receive(:duo_workflow_input_required_email)
          expect(::TodoService).not_to receive(:new)

          described_class.new(workflow: workflow, current_user: user, status_event: "require_input").execute
        end
      end

      context "when workflow is from a pipeline" do
        before do
          allow(workflow).to receive(:from_pipeline?).and_return(true)
        end

        context "when requiring input" do
          let(:mailer) { instance_double(ActionMailer::MessageDelivery, deliver_later: true) }
          let(:todo_service) { instance_double(::TodoService, duo_workflow_input_required: nil) }

          before do
            allow(::TodoService).to receive(:new).and_return(todo_service)
          end

          it "transitions to input_required, creates a todo, and enqueues an email to the initiator" do
            expect(todo_service).to receive(:duo_workflow_input_required).with(workflow)
            expect(::Notify).to receive(:duo_workflow_input_required_email)
              .with(workflow.user_id, workflow.id).and_return(mailer)
            expect(mailer).to receive(:deliver_later)

            result = described_class.new(workflow: workflow, current_user: user, status_event: "require_input").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("input required")
          end

          it "still succeeds when the mailer enqueue raises" do
            allow(todo_service).to receive(:duo_workflow_input_required)
            error = StandardError.new("mailer down")
            expect(::Notify).to receive(:duo_workflow_input_required_email).and_raise(error)
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              error, hash_including(workflow_id: workflow.id)
            )

            result = described_class.new(workflow: workflow, current_user: user, status_event: "require_input").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("input required")
          end
        end

        context "when resolving a pending input todo" do
          let(:todo_service) { instance_double(::TodoService, resolve_duo_workflow_input_required_todo: nil) }

          before do
            allow(::TodoService).to receive(:new).and_return(todo_service)
            workflow.require_input
          end

          %w[resume stop drop].each do |event|
            it "resolves the todo on #{event} but doesn't send emails" do
              expect(todo_service).to receive(:resolve_duo_workflow_input_required_todo).with(workflow)
              expect(::Notify).not_to receive(:duo_workflow_input_required_email)

              described_class.new(workflow: workflow, current_user: user, status_event: event).execute
            end
          end
        end
      end

      context "when stopping workflow" do
        it "can stop a workflow and enqueues pipeline cancellation async", :aggregate_failures do
          expect(Ai::DuoWorkflows::CancelAssociatedPipelinesWorker).to receive(:perform_async)
            .with(workflow.id, user.id)

          expect do
            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:success)
            expect(result[:message]).to eq("Workflow status updated")
          end.to trigger_internal_events("agent_platform_session_stopped")
                                 .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                                   user: workflow.user,
                                   project: workflow.project,
                                   additional_properties: {
                                     label: workflow.workflow_definition,
                                     value: workflow.id,
                                     property: "ide"
                                   })

          expect(workflow.reload.human_status_name).to eq("stopped")
        end

        it 'creates an audit event when stopping a workflow' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_session_stopped',
              author: user,
              scope: project,
              target: workflow,
              message: 'Duo session stopped'
            )
          )

          described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute
        end

        context 'when audit event creation fails for stop event' do
          let(:audit_error) { StandardError.new('Audit service unavailable') }

          before do
            allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
          end

          it 'tracks the exception and workflow update continues successfully' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              audit_error,
              hash_including(workflow_id: workflow.id)
            )

            result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("stopped")
          end
        end
      end

      it "can retry a running workflow", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "retry").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow already in status running")
        expect(workflow.reload.human_status_name).to eq("running")
      end

      context "when initial status is paused" do
        let(:workflow_initial_status_enum) { 2 } # status paused

        it "can resume a workflow", :aggregate_failures do
          expect do
            result = described_class.new(workflow: workflow, current_user: user, status_event: "resume").execute

            expect(result[:status]).to eq(:success)
            expect(result[:message]).to eq("Workflow status updated")
          end.to trigger_internal_events("agent_platform_session_resumed")
                  .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                    user: workflow.user,
                    project: workflow.project,
                    additional_properties: {
                      label: workflow.workflow_definition,
                      value: workflow.id,
                      property: "ide"
                    })
          expect(workflow.reload.human_status_name).to eq("running")
        end

        it 'creates an audit event when resuming a workflow' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_session_resumed',
              author: user,
              scope: project,
              target: workflow,
              message: 'Resumed Duo session'
            )
          )

          described_class.new(workflow: workflow, current_user: user, status_event: "resume").execute
        end

        context 'when audit event creation fails for resume event' do
          let(:audit_error) { StandardError.new('Audit service unavailable') }

          before do
            allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
          end

          it 'tracks the exception and workflow update continues successfully' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              audit_error,
              hash_including(workflow_id: workflow.id)
            )

            result = described_class.new(workflow: workflow, current_user: user, status_event: "resume").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("running")
          end
        end
      end

      context "when initial status is created" do
        let(:workflow_initial_status_enum) { 0 } # status created

        it "can start a workflow", :aggregate_failures do
          expect do
            result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

            expect(result[:status]).to eq(:success)
            expect(result[:message]).to eq("Workflow status updated")
          end.to trigger_internal_events("agent_platform_session_started")
                             .with(category: "Ai::DuoWorkflows::UpdateWorkflowStatusService",
                               user: workflow.user,
                               project: workflow.project,
                               additional_properties: {
                                 label: workflow.workflow_definition,
                                 value: workflow.id,
                                 property: "ide"
                               })

          expect(workflow.reload.human_status_name).to eq("running")
        end

        it 'creates an audit event when starting a workflow' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              name: 'duo_session_started',
              author: user,
              scope: project,
              target: workflow,
              message: 'Started Duo session'
            )
          )

          described_class.new(workflow: workflow, current_user: user, status_event: "start").execute
        end

        context 'when audit event creation fails' do
          let(:audit_error) { StandardError.new('Audit service unavailable') }

          before do
            allow(::Gitlab::Audit::Auditor).to receive(:audit).and_raise(audit_error)
          end

          it 'tracks the exception when starting a workflow and workflow update continues successfully' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              audit_error,
              hash_including(workflow_id: workflow.id)
            )

            result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("running")
          end
        end
      end

      context 'when transitioning to input_required' do
        let(:duo_workflow) do
          create(:duo_workflows_workflow, project: project, user: user, status: workflow_initial_status_enum,
            environment: "web")
        end

        it 'creates a todo for the workflow user' do
          expect do
            described_class.new(workflow: workflow, current_user: user, status_event: "require_input").execute
          end.to change {
            Todo.where(action: Todo::DUO_WORKFLOW_INPUT_REQUIRED, target: workflow, user: workflow.user).count
          }.by(1)
        end

        context 'for non pipeline workflows' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :update_duo_workflow, chat_workflow).and_return(true)
          end

          it 'does not sync input required todo event' do
            expect(::TodoService).not_to receive(:new)
            described_class.new(workflow: chat_workflow, current_user: user, status_event: "require_input").execute
          end
        end

        it 'does not call TodoService for status events unrelated to input_required' do
          expect(::TodoService).not_to receive(:new)
          described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute
        end
      end

      context 'when transitioning from input_required' do
        let(:duo_workflow) do
          create(:duo_workflows_workflow, :input_required, project: project, user: user, environment: "web")
        end

        where(:status_event) { %w[resume stop drop] }

        with_them do
          it 'resolves the input required todo' do
            todo = create(:todo, :duo_workflow_input_required, user: workflow.user, author: workflow.user,
              target: workflow, project: project)

            described_class.new(workflow: workflow, current_user: user, status_event: status_event).execute

            expect(todo.reload).to be_done
          end
        end

        context 'when workflow is not from pipeline' do
          before do
            allow(Ability).to receive(:allowed?).with(user, :update_duo_workflow, chat_workflow).and_return(true)
          end

          it 'does not sync input required todo on resume event' do
            expect(::TodoService).not_to receive(:new)
            described_class.new(workflow: chat_workflow, current_user: user, status_event: "resume").execute
          end
        end
      end

      it "does not update to not allowed status", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: user, status_event: "another_event").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not update workflow status, unsupported event: another_event")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("running")
      end

      it "does not finish failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not finish workflow that has status failed")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it "does not stop failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "stop").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not stop workflow that has status failed")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it "retries failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "retry").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow status updated")
        expect(workflow.reload.human_status_name).to eq("running")
      end

      it "does not drop finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "drop").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not drop workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not pause finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "pause").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not pause workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not resume finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "resume").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not resume workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not retry finished workflow", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "retry").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not retry workflow that has status finished")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      it "does not start failed workflow", :aggregate_failures do
        workflow.drop

        result = described_class.new(workflow: workflow, current_user: user, status_event: "start").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not start workflow that has status failed")
        expect(result[:reason]).to eq(:bad_request)
        expect(workflow.reload.human_status_name).to eq("failed")
      end

      it "does not allow user without permission to finish workflow", :aggregate_failures do
        result = described_class.new(workflow: workflow, current_user: another_user, status_event: "finish").execute

        expect(result[:status]).to eq(:error)
        expect(result[:message]).to eq("Can not update workflow")
        expect(result[:reason]).to eq(:unauthorized)
        expect(workflow.reload.human_status_name).to eq("running")
      end

      it "allows updating to current status", :aggregate_failures do
        workflow.finish

        result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

        expect(result[:status]).to eq(:success)
        expect(result[:message]).to eq("Workflow already in status finished")
        expect(workflow.reload.human_status_name).to eq("finished")
      end

      context "when duo_features_enabled settings is turned off" do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        after do
          project.project_setting.update!(duo_features_enabled: true)
        end

        it "returns not found", :aggregate_failures do
          result = described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute

          expect(result[:status]).to eq(:error)
          expect(result[:message]).to eq("Can not update workflow")
          expect(result[:reason]).to eq(:unauthorized)
          expect(workflow.reload.human_status_name).to eq("running")
        end
      end

      context 'on system note update' do
        let_it_be(:issue) { create(:issue, project: project) }
        let_it_be(:service_account_user) { create(:user, :service_account) }

        context 'when workflow is associated with an issue' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              service_account: service_account_user,
              status: workflow_initial_status_enum
            )
          end

          context 'when finishing workflow' do
            it 'creates a completion system note on the issue' do
              expect(SystemNoteService).to receive(:agent_session_completed).with(
                issue,
                project,
                workflow.id,
                service_account_user
              )

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "finish"
              ).execute
            end
          end

          context 'when dropping workflow' do
            it 'creates a failure system note on the issue with "dropped" reason' do
              expect(SystemNoteService).to receive(:agent_session_failed).with(
                issue,
                project,
                workflow.id,
                service_account_user,
                'dropped'
              )

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "drop"
              ).execute
            end
          end

          context 'when stopping workflow' do
            it 'creates a failure system note on the issue with "stopped" reason' do
              expect(SystemNoteService).to receive(:agent_session_failed).with(
                issue,
                project,
                workflow.id,
                service_account_user,
                'stopped'
              )

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "stop"
              ).execute
            end
          end

          context 'when pausing workflow' do
            it 'does not create a system note' do
              expect(SystemNoteService).not_to receive(:agent_session_completed)
              expect(SystemNoteService).not_to receive(:agent_session_failed)

              described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "pause"
              ).execute
            end
          end

          context 'when workflow has no service account' do
            let(:workflow) do
              create(
                :duo_workflows_workflow,
                project: project,
                user: user,
                issue: issue,
                status: workflow_initial_status_enum
              )
            end

            it 'calls SystemNoteService with nil author but does not create a note' do
              expect(SystemNoteService).to receive(:agent_session_completed).with(
                issue,
                project,
                workflow.id,
                nil
              ).and_call_original

              result = described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "finish"
              ).execute

              expect(result[:status]).to eq(:success)
              expect(issue.notes).to be_empty
            end
          end

          context 'when SystemNoteService raises an error' do
            before do
              allow(SystemNoteService).to receive(:agent_session_completed)
                .and_raise(StandardError, 'Note creation failed')
            end

            it 'tracks the exception and workflow update completes successfully' do
              expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
                instance_of(StandardError),
                hash_including(
                  workflow_id: workflow.id,
                  noteable_type: 'Issue',
                  noteable_id: issue.id
                )
              )

              result = described_class.new(
                workflow: workflow,
                current_user: user,
                status_event: "finish"
              ).execute

              expect(result[:status]).to eq(:success)
              expect(workflow.reload.human_status_name).to eq("finished")
            end
          end
        end

        context 'when workflow has no noteable association' do
          let(:workflow) do
            create(:duo_workflows_workflow, project: project, user: user, status: workflow_initial_status_enum)
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_completed)
            expect(SystemNoteService).not_to receive(:agent_session_failed)

            described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute
          end
        end

        context 'when the flow opts out of the agent session note' do
          let_it_be(:merge_request) { create(:merge_request, source_project: project) }

          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              merge_request: merge_request,
              service_account: service_account_user,
              workflow_definition: ::Ai::Catalog::FoundationalFlow.code_review.foundational_flow_reference,
              status: workflow_initial_status_enum
            )
          end

          it 'does not create a completion or failure system note' do
            expect(SystemNoteService).not_to receive(:agent_session_completed)
            expect(SystemNoteService).not_to receive(:agent_session_failed)

            described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute
          end
        end

        context 'when noteable does not have a project' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              status: workflow_initial_status_enum
            )
          end

          before do
            allow(issue).to receive(:project).and_return(nil)
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_completed)
            expect(SystemNoteService).not_to receive(:agent_session_failed)

            described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute
          end

          it 'still updates the workflow status successfully' do
            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("finished")
          end
        end

        context 'when noteable project is not present' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              status: workflow_initial_status_enum
            )
          end

          let(:empty_project) { instance_double(Project, present?: false) }

          before do
            allow(issue).to receive(:project).and_return(empty_project)
          end

          it 'does not create a system note' do
            expect(SystemNoteService).not_to receive(:agent_session_completed)
            expect(SystemNoteService).not_to receive(:agent_session_failed)

            described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute
          end

          it 'still updates the workflow status successfully' do
            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "finish"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("finished")
          end
        end

        context 'when system note creation fails for drop event' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              service_account: service_account_user,
              status: workflow_initial_status_enum
            )
          end

          before do
            allow(SystemNoteService).to receive(:agent_session_failed)
              .and_raise(StandardError, 'Failed note creation')
          end

          it 'tracks the exception but does not fail the workflow update' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(StandardError),
              hash_including(
                workflow_id: workflow.id,
                noteable_type: 'Issue',
                noteable_id: issue.id
              )
            )

            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "drop"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("failed")
          end
        end

        context 'when system note creation fails for stop event' do
          let(:workflow) do
            create(
              :duo_workflows_workflow,
              project: project,
              user: user,
              issue: issue,
              service_account: service_account_user,
              status: workflow_initial_status_enum
            )
          end

          before do
            allow(SystemNoteService).to receive(:agent_session_failed)
              .and_raise(StandardError, 'Failed note creation')
          end

          it 'tracks the exception but does not fail the workflow update' do
            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              instance_of(StandardError),
              hash_including(
                workflow_id: workflow.id,
                noteable_type: 'Issue',
                noteable_id: issue.id
              )
            )

            result = described_class.new(
              workflow: workflow,
              current_user: user,
              status_event: "stop"
            ).execute

            expect(result[:status]).to eq(:success)
            expect(workflow.reload.human_status_name).to eq("stopped")
          end
        end
      end

      describe 'session artifact sync' do
        context 'when ClickHouse is not enabled for analytics' do
          before do
            allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
          end

          it 'enqueues the sync worker' do
            expect(Ai::DuoWorkflows::SyncSessionArtifactWorker).to receive(:perform_async).with(workflow.id)

            described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute
          end
        end

        context 'when ClickHouse is enabled for analytics' do
          before do
            allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
          end

          it 'does not enqueue the sync worker' do
            expect(Ai::DuoWorkflows::SyncSessionArtifactWorker).not_to receive(:perform_async)

            described_class.new(workflow: workflow, current_user: user, status_event: "finish").execute
          end
        end
      end
    end
  end
end
