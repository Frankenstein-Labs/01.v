# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::TimeoutWorker, feature_category: :duo_code_review do
  subject(:worker) { described_class.new }

  let_it_be(:duo_code_review_bot) { create(:user, :duo_code_review_bot) }
  let_it_be(:project) { create(:project) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project) }

  describe '#perform' do
    let(:update_service) { instance_double(MergeRequests::UpdateReviewerStateService) }
    let(:service_result) { ServiceResponse.success }

    before do
      allow(MergeRequests::UpdateReviewerStateService)
        .to receive(:new)
        .with(project: merge_request.project, current_user: duo_code_review_bot)
        .and_return(update_service)

      allow(update_service).to receive(:execute).and_return(service_result)
      allow(Gitlab::AppLogger).to receive(:info)
    end

    context 'when merge request does not exist' do
      it 'returns early when merge request is not found' do
        expect(update_service).not_to receive(:execute)

        worker.perform(non_existing_record_id)
      end
    end

    context 'when reviewer is already in reviewed state' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: 'reviewed')
      end

      it 'returns early without updating state' do
        expect(update_service).not_to receive(:execute)

        worker.perform(merge_request.id)
      end

      it 'does not post an error comment' do
        expect(Notes::CreateService).not_to receive(:new)

        worker.perform(merge_request.id)
      end
    end

    context 'when reviewer is not in reviewed state' do
      let!(:progress_note) do
        create(
          :note,
          noteable: merge_request,
          project: project,
          author: duo_code_review_bot,
          system: true
        )
      end

      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: 'review_started')
        allow(merge_request).to receive(:duo_code_review_progress_note).and_return(progress_note)
        allow(MergeRequest).to receive(:find_by_id).with(merge_request.id).and_return(merge_request)
      end

      it 'posts an error comment to the merge request' do
        worker.perform(merge_request.id)

        merge_request.reload
        error_note = merge_request.notes.non_diff_notes.find_by(system: false)
        expect(error_note).to be_present
        expect(error_note.note).to eq(::Gitlab::Duo::CodeReview::Messages.timeout_error)
        expect(error_note.author).to eq(duo_code_review_bot)
      end

      it 'creates a todo for the error' do
        expect_any_instance_of(TodoService) do |service|
          expect(service).to receive(:new_review).with(merge_request, duo_code_review_bot)
        end

        worker.perform(merge_request.id)
      end

      it 'updates review state to reviewed' do
        worker.perform(merge_request.id)

        expect(update_service).to have_received(:execute).with(merge_request, 'reviewed')
      end

      it 'deletes the progress note' do
        expect { worker.perform(merge_request.id) }.to change { Note.exists?(progress_note.id) }.from(true).to(false)
      end

      it 'logs timeout reset message' do
        expect(Gitlab::AppLogger).to receive(:info).with(
          message: "Duo Code Review Flow timed out and was reset",
          event: "duo_code_review_flow_timeout_reset",
          unit_primitive: 'review_merge_request',
          merge_request_id: merge_request.id,
          project_id: project.id
        )

        worker.perform(merge_request.id)
      end

      it 'executes operations in the correct order' do
        call_order = []

        allow(Notes::CreateService).to receive(:new) do
          call_order << :post_error_comment
          instance_double(Notes::CreateService, execute: true)
        end

        allow(update_service).to receive(:execute) do
          call_order << :update_state
        end

        allow(progress_note).to receive(:destroy) do
          call_order << :delete_progress_note
        end

        worker.perform(merge_request.id)

        expect(call_order).to eq([:post_error_comment, :update_state, :delete_progress_note])
      end

      context 'when there is no progress note' do
        before do
          allow(merge_request).to receive(:duo_code_review_progress_note).and_return(nil)
        end

        it 'does not raise an error' do
          expect { worker.perform(merge_request.id) }.not_to raise_error
        end

        it 'does not post an error comment' do
          expect(Notes::CreateService).not_to receive(:new)

          worker.perform(merge_request.id)
        end

        it 'still updates review state and logs' do
          worker.perform(merge_request.id)

          expect(update_service).to have_received(:execute).with(merge_request, 'reviewed')
          expect(Gitlab::AppLogger).to have_received(:info)
        end
      end
    end

    context 'when an error occurs' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot, state: 'review_started')
        allow(update_service).to receive(:execute).and_raise(StandardError.new('Something went wrong'))
      end

      it 'tracks the exception' do
        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          instance_of(StandardError),
          merge_request_id: merge_request.id
        )

        worker.perform(merge_request.id)
      end

      it 'does not raise the error' do
        expect { worker.perform(merge_request.id) }.not_to raise_error
      end
    end
  end
end
