# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::CreateCommentsService, feature_category: :duo_code_review do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }
  let_it_be(:review_bot) { create(:user, :duo_code_review_bot) }

  let(:review_output) { '{"comments": []}' }
  let(:workflow_id) { nil }
  let(:progress_note) { nil }
  let(:service) do
    described_class.new(
      user: user,
      merge_request: merge_request,
      review_output: review_output,
      progress_note: progress_note,
      workflow_id: workflow_id
    )
  end

  describe '#execute' do
    subject(:execute) { service.execute }

    context 'when progress note is present' do
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
      let(:process_result) { ServiceResponse.success(message: 'Success', payload: { draft_notes: [] }) }
      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)
      end

      it 'deletes the progress note in ensure block' do
        expect(progress_note).to receive(:destroy)
        execute
      end

      it 'updates review state to reviewed' do
        expect_next_instance_of(MergeRequests::UpdateReviewerStateService) do |instance|
          expect(instance).to receive(:execute).with(merge_request, 'reviewed')
        end
        execute
      end
    end

    context 'when ProcessCommentsService returns an error' do
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
      let(:error_message) { 'Processing failed' }
      let(:process_result) do
        ServiceResponse.error(
          message: error_message,
          payload: { create_todo: true }
        )
      end

      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(progress_note).to receive(:destroy)
      end

      it 'returns an error response' do
        expect(execute).to be_error
        expect(execute.message).to eq(error_message)
      end

      it 'updates progress note with todo' do
        expect(service).to receive(:update_progress_note).with(error_message, with_todo: true)
        execute
      end
    end

    context 'when ProcessCommentsService returns an error without create_todo in payload' do
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
      let(:error_message) { 'Processing failed' }
      let(:process_result) { ServiceResponse.error(message: error_message, payload: {}) }
      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(progress_note).to receive(:destroy)
      end

      it 'returns an error response' do
        expect(execute).to be_error
      end

      it 'updates progress note without creating a todo' do
        expect(service).to receive(:update_progress_note).with(error_message, with_todo: false)
        execute
      end
    end

    context 'when ProcessCommentsService returns success with draft notes' do
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
      let(:draft_note) { instance_double(DraftNote) }
      let(:draft_notes) { [draft_note] }
      let(:summary) { 'Review summary' }
      let(:metrics) do
        instance_double(
          Ai::DuoWorkflows::CodeReview::ProcessCommentsService::Metrics,
          total_comments: 1,
          comments_with_valid_path: 1,
          comments_with_valid_line: 1,
          comments_with_custom_instructions: 0,
          comments_line_matched_by_content: 0,
          draft_notes_created: 1
        )
      end

      let(:process_result) do
        ServiceResponse.success(
          message: summary,
          payload: {
            draft_notes: draft_notes,
            metrics: metrics
          }
        )
      end

      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      let(:publish_service) { instance_double(DraftNotes::PublishService, execute: true) }

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService).to receive(:new).and_return(process_service)
        allow(Ability).to receive(:allowed?).with(user, :create_note, merge_request).and_return(true)
        allow(DraftNote).to receive(:bulk_insert_and_keep_commits!)
        allow(DraftNotes::PublishService).to receive(:new).and_return(publish_service)
        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(service).to receive(:track_review_merge_request_event)
        allow(progress_note).to receive(:destroy)
      end

      it 'returns success' do
        expect(execute).to be_success
      end

      it 'publishes draft notes' do
        expect(DraftNote).to receive(:bulk_insert_and_keep_commits!).with(draft_notes, batch_size: 20)
        expect(DraftNotes::PublishService).to receive(:new).with(merge_request, review_bot).and_return(publish_service)
        expect(publish_service).to receive(:execute).with(executing_user: user)
        execute
      end

      it 'logs metrics' do
        expect(service).to receive(:log_metrics).with(metrics)
        execute
      end

      it 'tracks the correct event' do
        expect(service).to receive(:track_review_merge_request_event)
          .with('post_comment_duo_code_review_on_diff', additional_properties: { value: 1 })
        execute
      end
    end

    context 'when ProcessCommentsService returns success with no draft notes' do
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
      let(:message) { 'No comments to add' }
      let(:process_result) do
        ServiceResponse.success(
          message: message,
          payload: { draft_notes: [] }
        )
      end

      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(service).to receive(:track_review_merge_request_event)
        allow(progress_note).to receive(:destroy)
      end

      it 'returns success' do
        expect(execute).to be_success
      end

      it 'updates progress note with todo' do
        expect(service).to receive(:update_progress_note).with(message, with_todo: true)
        execute
      end

      it 'tracks the no issues event' do
        expect(service).to receive(:track_review_merge_request_event)
          .with('find_no_issues_duo_code_review_after_review')
        execute
      end

      it 'does not publish draft notes' do
        expect(service).not_to receive(:publish_draft_notes)
        execute
      end
    end

    context 'when draft_notes key is absent from the ProcessCommentsService payload' do
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
      let(:process_result) { ServiceResponse.success(message: 'OK', payload: {}) }
      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(service).to receive(:track_review_merge_request_event)
        allow(progress_note).to receive(:destroy)
      end

      it 'returns success' do
        expect(execute).to be_success
      end

      it 'takes the empty-notes path without raising' do
        expect(service).to receive(:track_review_merge_request_event)
          .with('find_no_issues_duo_code_review_after_review')
        execute
      end
    end

    context 'when progress_note is nil' do
      # Uses the top-level default: let(:progress_note) { nil }
      let(:process_result) { ServiceResponse.success(message: 'OK', payload: { draft_notes: [] }) }
      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_review_state)
        allow(service).to receive(:track_review_merge_request_event)
      end

      it 'returns success without raising' do
        expect(execute).to be_success
      end

      it 'does not create any notes' do
        expect(Notes::CreateService).not_to receive(:new)
        execute
      end
    end

    context 'when a StandardError occurs' do
      let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
      let(:error) { StandardError.new('Something went wrong') }

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_raise(error)

        allow(service).to receive(:track_review_merge_request_exception)
        allow(service).to receive(:track_review_merge_request_event)
        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(progress_note).to receive(:destroy)
      end

      it 'returns an error with generic message' do
        expect(execute).to be_error
        expect(execute.message).to include('I have encountered some problems')
      end

      it 'tracks the exception' do
        expect(service).to receive(:track_review_merge_request_exception).with(error)
        execute
      end

      it 'tracks the error event' do
        expect(service).to receive(:track_review_merge_request_event)
          .with('encounter_duo_code_review_error_during_review')
        execute
      end

      it 'updates progress note with todo' do
        expect(service).to receive(:update_progress_note)
          .with(a_string_including('I have encountered some problems'), with_todo: true)
        execute
      end

      it 'still cleans up resources' do
        expect(progress_note).to receive(:destroy)
        expect(service).to receive(:update_review_state).with('reviewed')
        execute
      end
    end
  end

  describe '#publish_draft_notes' do
    let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }
    let(:draft_note) { instance_double(DraftNote) }
    let(:draft_notes) { [draft_note] }
    let(:summary) { 'Review summary' }

    context 'when user can create notes' do
      let(:publish_service) { instance_double(DraftNotes::PublishService) }

      before do
        allow(Ability).to receive(:allowed?).with(user, :create_note, merge_request).and_return(true)
        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:track_review_merge_request_event)
      end

      it 'bulk inserts draft notes' do
        expect(DraftNote).to receive(:bulk_insert_and_keep_commits!)
          .with(draft_notes, batch_size: 20)
        expect(DraftNotes::PublishService).to receive(:new)
          .with(merge_request, review_bot)
          .and_return(publish_service)
        expect(publish_service).to receive(:execute).with(executing_user: user)

        service.send(:publish_draft_notes, draft_notes, summary)
      end

      it 'updates progress note with summary' do
        allow(DraftNote).to receive(:bulk_insert_and_keep_commits!)
        publish_service = instance_double(DraftNotes::PublishService, execute: true)
        allow(DraftNotes::PublishService).to receive(:new).and_return(publish_service)

        expect(service).to receive(:update_progress_note).with(summary)

        service.send(:publish_draft_notes, draft_notes, summary)
      end

      it 'tracks the comment event with count' do
        allow(DraftNote).to receive(:bulk_insert_and_keep_commits!)
        publish_service = instance_double(DraftNotes::PublishService, execute: true)
        allow(DraftNotes::PublishService).to receive(:new).and_return(publish_service)

        expect(service).to receive(:track_review_merge_request_event)
          .with('post_comment_duo_code_review_on_diff', additional_properties: { value: 1 })

        service.send(:publish_draft_notes, draft_notes, summary)
      end
    end

    context 'when user cannot create notes' do
      before do
        allow(Ability).to receive(:allowed?).with(user, :create_note, merge_request).and_return(false)
      end

      it 'does not publish draft notes' do
        expect(DraftNote).not_to receive(:bulk_insert_and_keep_commits!)
        expect(DraftNotes::PublishService).not_to receive(:new)

        service.send(:publish_draft_notes, draft_notes, summary)
      end
    end

    context 'when draft notes are empty' do
      let(:draft_notes) { [] }

      before do
        allow(Ability).to receive(:allowed?).with(user, :create_note, merge_request).and_return(true)
      end

      it 'does not publish draft notes' do
        expect(DraftNote).not_to receive(:bulk_insert_and_keep_commits!)
        expect(DraftNotes::PublishService).not_to receive(:new)

        service.send(:publish_draft_notes, draft_notes, summary)
      end
    end
  end

  describe '#log_metrics' do
    let(:metrics) do
      instance_double(
        Ai::DuoWorkflows::CodeReview::ProcessCommentsService::Metrics,
        total_comments: 5,
        comments_with_valid_path: 4,
        comments_with_valid_line: 3,
        comments_with_custom_instructions: 1,
        comments_line_matched_by_content: 2,
        draft_notes_created: 3
      )
    end

    context 'when duo_code_review_response_logging is enabled' do
      before do
        stub_feature_flags(duo_code_review_response_logging: true)
        allow(service).to receive(:log_review_merge_request_event)
      end

      it 'logs the metrics with correct attributes' do
        expect(service).to receive(:log_review_merge_request_event).with(
          message: "LLM response comments metrics",
          event: "review_merge_request_llm_response_comments",
          merge_request_id: merge_request.id,
          total_comments: 5,
          comments_with_valid_path: 4,
          comments_with_valid_line: 3,
          comments_with_custom_instructions: 1,
          comments_line_matched_by_content: 2,
          draft_notes_created: 3
        )

        service.send(:log_metrics, metrics)
      end
    end

    context 'when duo_code_review_response_logging is disabled' do
      before do
        stub_feature_flags(duo_code_review_response_logging: false)
        allow(service).to receive(:log_review_merge_request_event)
      end

      it 'does not log metrics' do
        expect(service).not_to receive(:log_review_merge_request_event)

        service.send(:log_metrics, metrics)
      end
    end
  end

  describe '#update_review_state' do
    let(:update_service) { instance_double(MergeRequests::UpdateReviewerStateService) }

    before do
      allow(Users::Internal).to receive(:duo_code_review_bot).and_return(review_bot)
    end

    it 'calls UpdateReviewerStateService' do
      expect(MergeRequests::UpdateReviewerStateService).to receive(:new)
        .with(project: project, current_user: review_bot)
        .and_return(update_service)
      expect(update_service).to receive(:execute).with(merge_request, 'reviewed')

      service.send(:update_review_state, 'reviewed')
    end

    context 'when merge_request is nil' do
      let(:merge_request) { nil }

      it 'does not call UpdateReviewerStateService' do
        expect(MergeRequests::UpdateReviewerStateService).not_to receive(:new)

        service.send(:update_review_state, 'reviewed')
      end
    end
  end

  describe 'comprehensive error handling' do
    subject(:execute) { service.execute }

    let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }

    context 'when ProcessCommentsService raises StandardError' do
      let(:original_error) { StandardError.new('Processing failed') }

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_raise(original_error)

        allow(service).to receive(:track_review_merge_request_exception)
        allow(service).to receive(:track_review_merge_request_event)
        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(progress_note).to receive(:destroy)
      end

      it 'handles the error gracefully' do
        result = execute
        expect(result).to be_error
        expect(result.message).to include('I have encountered some problems')
      end

      it 'tracks the original exception' do
        expect(service).to receive(:track_review_merge_request_exception).with(original_error)
        execute
      end

      it 'tracks the error event' do
        expect(service).to receive(:track_review_merge_request_event)
          .with('encounter_duo_code_review_error_during_review')
        execute
      end

      it 'updates progress note with generic error message' do
        expect(service).to receive(:update_progress_note)
          .with(a_string_including('I have encountered some problems'), with_todo: true)
        execute
      end

      it 'still performs cleanup in ensure block' do
        expect(service).to receive(:update_review_state).with('reviewed')
        expect(progress_note).to receive(:destroy)
        execute
      end
    end

    context 'when update_progress_note fails' do
      let(:process_result) { ServiceResponse.success(message: 'Success', payload: { draft_notes: [] }) }
      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      let(:notes_error) { StandardError.new('Notes service failed') }

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_progress_note).and_raise(notes_error)
        allow(service).to receive(:track_review_merge_request_exception)
        allow(service).to receive(:track_review_merge_request_event)
        allow(service).to receive(:update_review_state)
        allow(progress_note).to receive(:destroy)
      end

      it 'allows notes service errors to propagate' do
        expect { execute }.to raise_error(StandardError, 'Notes service failed')
      end

      it 'still tracks the original exception before the notes error' do
        expect(service).to receive(:track_review_merge_request_exception).ordered
        expect { execute }.to raise_error(StandardError, 'Notes service failed')
      end
    end

    context 'when progress_note destruction fails' do
      let(:process_result) { ServiceResponse.success(message: 'Success', payload: { draft_notes: [] }) }
      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:update_review_state)
        allow(service).to receive(:track_review_merge_request_event)
        allow(progress_note).to receive(:destroy).and_raise('Destruction failed')
      end

      it 'allows destruction errors to propagate' do
        expect { execute }.to raise_error('Destruction failed')
      end
    end

    context 'when review state update fails' do
      let(:process_result) { ServiceResponse.success(message: 'Success', payload: { draft_notes: [] }) }
      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(service).to receive(:update_progress_note)
        allow(service).to receive(:track_review_merge_request_event)
        allow(service).to receive(:update_review_state).and_raise('State update failed')
        allow(progress_note).to receive(:destroy)
      end

      it 'allows state update errors to propagate' do
        expect { execute }.to raise_error('State update failed')
      end
    end
  end

  describe 'event tracking verification' do
    subject(:execute) { service.execute }

    let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }

    before do
      allow(service).to receive(:update_progress_note)
      allow(service).to receive(:update_review_state)
      allow(progress_note).to receive(:destroy)
    end

    context 'when draft notes are published' do
      let(:draft_note) { instance_double(DraftNote) }
      let(:draft_notes) { [draft_note, draft_note, draft_note] }
      let(:summary) { 'Review summary' }
      let(:process_result) do
        ServiceResponse.success(
          message: summary,
          payload: { draft_notes: draft_notes }
        )
      end

      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)

        allow(Ability).to receive(:allowed?).with(user, :create_note, merge_request).and_return(true)
        allow(DraftNote).to receive(:bulk_insert_and_keep_commits!)
        allow(DraftNotes::PublishService).to receive_message_chain(:new, :execute)
      end

      it 'tracks comment posting event with correct count' do
        expect(service).to receive(:track_review_merge_request_event)
          .with('post_comment_duo_code_review_on_diff', additional_properties: { value: 3 })
        execute
      end

      it 'does not track no issues event when comments exist' do
        expect(service).not_to receive(:track_review_merge_request_event)
          .with('find_no_issues_duo_code_review_after_review')
        execute
      end
    end

    context 'when no draft notes are created' do
      let(:process_result) do
        ServiceResponse.success(
          message: 'No comments',
          payload: { draft_notes: [] }
        )
      end

      let(:process_service) do
        instance_double(Ai::DuoWorkflows::CodeReview::ProcessCommentsService, execute: process_result)
      end

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_return(process_service)
      end

      it 'tracks no issues found event' do
        expect(service).to receive(:track_review_merge_request_event)
          .with('find_no_issues_duo_code_review_after_review')
        execute
      end

      it 'does not track comment posting event' do
        expect(service).not_to receive(:track_review_merge_request_event)
          .with('post_comment_duo_code_review_on_diff', anything)
        execute
      end
    end

    context 'when StandardError occurs' do
      let(:error) { StandardError.new('Unexpected error') }

      before do
        allow(Ai::DuoWorkflows::CodeReview::ProcessCommentsService)
          .to receive(:new).and_raise(error)

        allow(service).to receive(:track_review_merge_request_exception)
        allow(service).to receive(:track_review_merge_request_event)
      end

      it 'tracks both exception and error event' do
        expect(service).to receive(:track_review_merge_request_exception).with(error)
        expect(service).to receive(:track_review_merge_request_event)
          .with('encounter_duo_code_review_error_during_review')
        execute
      end
    end
  end
end
