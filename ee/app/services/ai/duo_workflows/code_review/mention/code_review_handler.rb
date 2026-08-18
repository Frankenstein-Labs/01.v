# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      module Mention
        class CodeReviewHandler < BaseHandler
          def execute
            merge_request = note.noteable

            if merge_request.duo_code_review_progress_note.present?
              create_note_on(review_in_progress_note)
              return
            end

            if merge_request.reviewer_ids.include?(duo_code_review_bot.id)
              ::MergeRequests::RequestReviewService.new(
                project: merge_request.project,
                current_user: note.author
              ).execute(merge_request, duo_code_review_bot)
            else
              ::MergeRequests::UpdateReviewersService.new(
                project: merge_request.project,
                current_user: note.author,
                params: { reviewer_ids: merge_request.reviewer_ids | [duo_code_review_bot.id] }
              ).execute(merge_request)
            end
          end

          private

          def review_in_progress_note
            s_("DuoCodeReview|I'm already reviewing this merge request. I'll post my feedback when I'm done.")
          end
        end
      end
    end
  end
end
