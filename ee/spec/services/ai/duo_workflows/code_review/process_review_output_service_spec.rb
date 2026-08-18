# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::ProcessReviewOutputService, feature_category: :duo_code_review do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project) }

  let(:review_output) { '<review></review>' }
  let(:workflow_id) { 99 }

  let(:service) do
    described_class.new(
      user: user,
      project: project,
      merge_request: merge_request,
      review_output: review_output,
      workflow_id: workflow_id
    )
  end

  describe '#valid?' do
    context 'when review_output is blank' do
      where(:blank_value) { [nil, ''] }

      with_them do
        let(:review_output) { blank_value }

        it 'returns false without checking diff files' do
          expect(merge_request).not_to receive(:ai_reviewable_diff_files)

          expect(service.valid?).to be(false)
        end

        it 'sets message to the invalid_review_output text' do
          service.valid?

          expect(service.message).to include(::Gitlab::Duo::CodeReview::Messages.invalid_review_output)
        end
      end
    end

    context 'when review_output is present but there are no reviewable diff files' do
      before do
        allow(merge_request).to receive(:ai_reviewable_diff_files).and_return([])
        allow(merge_request).to receive_message_chain(:diffs, :diff_files).and_return([])
      end

      it 'returns false' do
        expect(service.valid?).to be(false)
      end

      it 'sets message to the nothing_to_review text' do
        service.valid?

        expect(service.message).to include(::Gitlab::Duo::CodeReview::Messages.nothing_to_review)
      end
    end

    context 'when there are reviewable diff files and review_output is present' do
      before do
        allow(merge_request).to receive(:ai_reviewable_diff_files)
          .and_return([instance_double(Gitlab::Diff::File, file_path: 'a.rb')])
        allow(merge_request).to receive_message_chain(:diffs, :diff_files).and_return([])
      end

      it 'returns true' do
        expect(service.valid?).to be(true)
      end

      it 'leaves message nil' do
        service.valid?

        expect(service.message).to be_nil
      end
    end

    it 'is memoized — computed only once' do
      allow(merge_request).to receive(:ai_reviewable_diff_files)
        .and_return([instance_double(Gitlab::Diff::File, file_path: 'a.rb')])
      allow(merge_request).to receive_message_chain(:diffs, :diff_files).and_return([])

      service.valid?
      service.valid?

      expect(merge_request).to have_received(:ai_reviewable_diff_files).once
    end
  end

  describe '#execute' do
    let(:progress_note) { create(:note, noteable: merge_request, project: merge_request.project) }

    before do
      allow(merge_request).to receive(:duo_code_reviewed?).and_return(false)
      allow(service).to receive(:find_or_create_progress_note).and_return(progress_note)
      allow(Ai::DuoWorkflows::CodeReview::PublishCommentsWorker).to receive(:perform_async)
    end

    it 'enqueues PublishCommentsWorker with progress_note_id as positional arg' do
      expect(Ai::DuoWorkflows::CodeReview::PublishCommentsWorker)
        .to receive(:perform_async)
        .with(
          workflow_id,
          merge_request.id,
          user.id,
          progress_note.id,
          review_output
        )

      service.execute
    end

    it 'returns a success ServiceResponse' do
      expect(service.execute).to be_success
    end

    context 'when the review is already completed' do
      before do
        allow(merge_request).to receive(:duo_code_reviewed?).and_return(true)
      end

      it 'returns success silently without enqueueing a worker' do
        expect(Ai::DuoWorkflows::CodeReview::PublishCommentsWorker).not_to receive(:perform_async)

        expect(service.execute).to be_success
      end

      it 'does not attempt to create a progress note' do
        expect(service).not_to receive(:find_or_create_progress_note)

        service.execute
      end
    end

    context 'when progress note cannot be found or created' do
      before do
        allow(service).to receive(:find_or_create_progress_note).and_return(nil)
      end

      it 'returns an error without enqueueing the worker' do
        expect(Ai::DuoWorkflows::CodeReview::PublishCommentsWorker).not_to receive(:perform_async)

        result = service.execute

        expect(result).to be_error
        expect(result.message).to match(/Can't create the progress note/)
      end
    end

    context 'without a workflow_id' do
      let(:service) do
        described_class.new(user: user, project: project, merge_request: merge_request, review_output: review_output)
      end

      it 'enqueues the worker with nil workflow_id' do
        expect(Ai::DuoWorkflows::CodeReview::PublishCommentsWorker)
          .to receive(:perform_async)
          .with(nil, merge_request.id, user.id, progress_note.id, review_output)

        service.execute
      end
    end
  end
end
