# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService, feature_category: :duo_agent_platform do
  subject(:service) { described_class.new(user: user, merge_request: merge_request) }

  let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:user) { create(:user, developer_of: project) }
  let_it_be_with_reload(:merge_request) do
    create(:merge_request, source_project: project, target_project: project) do |mr|
      mr.merge_request_reviewers.create!(reviewer: duo_code_review_bot)
    end
  end

  let_it_be_with_reload(:reviewer) { merge_request.find_reviewer(duo_code_review_bot) }

  shared_examples_for 'updates merge request status' do |status|
    it "updates the merge request status to #{status}" do
      expect { service.execute }.to change { reviewer.reload.state }.to(status)
    end
  end

  shared_examples_for 'adds an error note' do
    it 'posts an error comment to the merge request' do
      expect_next_instance_of(::Notes::CreateService) do |notes_service|
        expect(notes_service).to receive(:execute).and_call_original
      end

      service.execute

      merge_request.reload
      error_note = merge_request.notes.non_diff_notes.last
      expect(error_note.note).to eq(expected_error_message)
      expect(error_note.author).to eq(duo_code_review_bot)
    end
  end

  shared_examples_for 'tracks an exception for unknown failures' do
    it 'tracks failure as an error with reason' do
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        expected_exception,
        {
          reason: expected_reason.to_s,
          unit_primitive: 'duo_agent_platform',
          merge_request_id: merge_request.id,
          merge_request_iid: merge_request.iid,
          project_id: merge_request.project_id,
          user_id: user.id
        }
      )

      service.execute
    end
  end

  shared_examples_for 'does not track an exception for known failures' do
    it 'does not track an exception for known failures' do
      expect(Gitlab::ErrorTracking).not_to receive(:track_exception)

      service.execute
    end
  end

  describe '#execute' do
    before do
      allow(::Ai::DuoWorkflows::CreateAndStartWorkflowService)
        .to receive(:new)
        .with(
          container: merge_request.project,
          resource: merge_request,
          current_user: user,
          workflow_definition: ::Ai::Catalog::FoundationalFlow['code_review/v1'],
          goal: merge_request.iid,
          source_branch: merge_request.source_branch
        ).and_return(
          instance_double(
            ::Ai::DuoWorkflows::CreateAndStartWorkflowService,
            execute: create_and_start_service_result
          )
        )
    end

    context 'when workflow starts successfully' do
      let(:workflow) do
        create(:duo_workflows_workflow, project: project, user: user)
      end

      let(:create_and_start_service_result) do
        ServiceResponse.success(payload: { workflow: workflow, workload_id: double })
      end

      include_examples 'updates merge request status', 'review_started'

      it 'schedules timeout cleanup job for 30 minutes' do
        expect(::Ai::DuoWorkflows::CodeReview::TimeoutWorker)
          .to receive(:perform_in)
          .with(30.minutes, merge_request.id)

        service.execute
      end

      it 'tracks review request event for author' do
        merge_request.update!(author: user)

        expect(service).to receive(:track_internal_event).with(
          'request_review_duo_code_review_on_mr_by_author',
          user: user,
          project: project,
          additional_properties: { property: merge_request.id.to_s }
        )

        service.execute
      end

      it 'tracks review request event for non-author' do
        other_user = create(:user, developer_of: project)
        merge_request.update!(author: other_user)

        expect(service).to receive(:track_internal_event).with(
          'request_review_duo_code_review_on_mr_by_non_author',
          user: user,
          project: project,
          additional_properties: { property: merge_request.id.to_s }
        )

        service.execute
      end
    end

    context 'when workflow fails to start' do
      context 'when code review flow is disabled' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Workflow not enabled for this project/namespace',
            reason: :flow_not_enabled
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.foundational_flow_not_enabled_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when code review flow is enabled but service account is not available' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Could not resolve the service account for this flow',
            reason: :invalid_service_account
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.missing_service_account_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when user has exceeded usage quota' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Usage quota exceeded',
            reason: :usage_quota_exceeded
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.usage_quota_exceeded_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when user does not have a default namespace set' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Namespace is required',
            reason: :namespace_missing
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.namespace_missing_error(user) }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when user does not have permission to create Duo workflow pipeline' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'forbidden to access duo workflow',
            reason: :cannot_create_workflow_pipeline
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) do
            ::Gitlab::Duo::CodeReview::Messages.insufficient_workload_permissions_error(user)
          end
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when CI workload fails to be created' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Error in creating workload',
            reason: :workload_failure
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.workload_creation_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when workflow workload association fails to persist' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Validation failed',
            reason: :workflow_workload_failure
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.workload_creation_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when the feature is unavailable for the user' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Can not execute workflow in CI',
            reason: :feature_unavailable
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.feature_unavailable_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when duo workflow token cannot be obtained' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Could not obtain Duo Workflow token',
            reason: :invalid_duo_workflow_token
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.invalid_token_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when oauth token cannot be obtained' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Could not obtain authentication token',
            reason: :invalid_oauth_token
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.invalid_token_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'when source ref cannot be found' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Source ref not found',
            reason: :source_ref_not_found
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.source_ref_not_found_error }
        end

        include_examples 'does not track an exception for known failures'
      end

      context 'with a generic failure reason' do
        let(:create_and_start_service_result) do
          ServiceResponse.error(
            message: 'Something unexpected happened',
            reason: :unknown_reason
          )
        end

        include_examples 'updates merge request status', 'reviewed'

        include_examples 'adds an error note' do
          let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.could_not_start_workflow_error }
        end

        include_examples 'tracks an exception for unknown failures' do
          let(:expected_reason) { create_and_start_service_result.reason }
          let(:expected_exception) do
            Ai::DuoWorkflows::CodeReview::ReviewMergeRequestService::CouldNotStartWorkflowError.new(
              create_and_start_service_result.message
            )
          end
        end
      end
    end

    context 'when start workflow raises an exception' do
      let(:create_and_start_service_result) { -> { raise StandardError, 'Unexpected error' } }
      let(:exception) { StandardError.new('Unexpected error') }

      before do
        allow_next_instance_of(::Ai::DuoWorkflows::CreateAndStartWorkflowService) do |start_workflow|
          allow(start_workflow).to receive(:execute).and_raise(exception)
        end
      end

      include_examples 'updates merge request status', 'reviewed'

      include_examples 'adds an error note' do
        let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.exception_when_starting_workflow_error }
      end

      include_examples 'tracks an exception for unknown failures' do
        let(:expected_reason) { :exception }
        let(:expected_exception) { exception }
      end

      it 'returns error response' do
        result = service.execute

        expect(result.error?).to be(true)
        expect(result.message).to eq('Unexpected error')
      end

      it 'creates a todo for the merge request' do
        expect { service.execute }
          .to change { Todo.count }.by(1)

        todo = Todo.last
        expect(todo.action).to eq(Todo::REVIEW_SUBMITTED)
        expect(todo.author).to eq(duo_code_review_bot)
      end
    end

    context 'when an exception is raised after starting the workflow' do
      let(:workflow) do
        create(:duo_workflows_workflow, project: project, user: user)
      end

      let(:create_and_start_service_result) do
        ServiceResponse.success(payload: { workflow: workflow, workload_id: double })
      end

      let(:exception) { StandardError.new('Something went wrong') }

      before do
        allow(::Ai::DuoWorkflows::CodeReview::TimeoutWorker)
          .to receive(:perform_in)
          .and_raise(exception)
      end

      include_examples 'updates merge request status', 'reviewed'

      include_examples 'adds an error note' do
        let(:expected_error_message) { ::Gitlab::Duo::CodeReview::Messages.exception_when_starting_workflow_error }
      end

      include_examples 'tracks an exception for unknown failures' do
        let(:expected_reason) { :exception }
        let(:expected_exception) { exception }
      end

      it 'cleans up the progress note' do
        progress_note = instance_double(::Note)

        expect_next_instance_of(::SystemNotes::MergeRequestsService) do |note_service|
          expect(note_service).to receive(:duo_code_review_started).and_return(progress_note)
        end

        expect(progress_note).to receive(:destroy)

        service.execute
      end
    end
  end
end
