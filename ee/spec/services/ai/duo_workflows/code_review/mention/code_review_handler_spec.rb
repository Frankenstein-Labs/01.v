# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::CodeReview::Mention::CodeReviewHandler, feature_category: :duo_code_review do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be_with_reload(:merge_request) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:author) { create(:user) }
  let_it_be(:duo_code_review_bot) { ::Users::Internal.in_organization(project.organization_id).duo_code_review_bot }

  let_it_be(:note) do
    create(
      :diff_note_on_merge_request,
      noteable: merge_request,
      project: project,
      author: author
    )
  end

  subject(:handler) { described_class.new(note) }

  describe '#execute' do
    context 'when a review is already in progress' do
      before do
        allow(merge_request).to receive(:duo_code_review_progress_note).and_return(instance_double(Note))
        allow(note).to receive(:noteable).and_return(merge_request)
      end

      it 'posts a review-in-progress reply and does not modify reviewers', :aggregate_failures do
        expect(Notes::CreateService).to receive(:new).with(
          project,
          duo_code_review_bot,
          hash_including(
            note: s_("DuoCodeReview|I'm already reviewing this merge request. I'll post my feedback when I'm done."),
            in_reply_to_discussion_id: note.discussion_id
          )
        ).and_call_original

        expect(::MergeRequests::RequestReviewService).not_to receive(:new)
        expect(::MergeRequests::UpdateReviewersService).not_to receive(:new)

        handler.execute
      end
    end

    context 'when the bot is already a reviewer' do
      before do
        merge_request.merge_request_reviewers.create!(reviewer: duo_code_review_bot)
      end

      it 'calls RequestReviewService to re-request a review' do
        expect_next_instance_of(
          ::MergeRequests::RequestReviewService,
          project: merge_request.project, current_user: author
        ) do |svc|
          expect(svc).to receive(:execute).with(merge_request, duo_code_review_bot)
        end

        handler.execute
      end
    end

    context 'when the bot is not yet a reviewer' do
      it 'calls UpdateReviewersService to add the bot as a reviewer' do
        expect_next_instance_of(
          ::MergeRequests::UpdateReviewersService,
          project: merge_request.project,
          current_user: author,
          params: { reviewer_ids: merge_request.reviewer_ids | [duo_code_review_bot.id] }
        ) do |svc|
          expect(svc).to receive(:execute).with(merge_request)
        end

        handler.execute
      end
    end
  end
end
