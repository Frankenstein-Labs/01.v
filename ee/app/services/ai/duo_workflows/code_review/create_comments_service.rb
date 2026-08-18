# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class CreateCommentsService
        include ::Gitlab::Utils::StrongMemoize
        include ::Ai::DuoWorkflows::CodeReview::Observability

        def initialize(
          user:,
          merge_request:,
          review_output:,
          progress_note:,
          workflow_id: nil
        )
          @user = user
          @merge_request = merge_request
          @review_output = review_output
          @progress_note = progress_note
          @workflow_id = workflow_id
        end

        def execute
          processed_comments = ProcessCommentsService.new(
            user: user,
            merge_request: merge_request,
            review_output: review_output,
            review_bot: review_bot
          ).execute

          metrics = processed_comments.payload[:metrics]
          message = processed_comments.message

          log_metrics(metrics) if metrics

          if processed_comments.error?
            create_todo = processed_comments.payload.fetch(:create_todo, false)
            update_progress_note(message, with_todo: create_todo)
            return error(message)
          end

          draft_notes = Array(processed_comments.payload[:draft_notes])

          if draft_notes.empty?
            update_progress_note(message, with_todo: true)
            track_review_merge_request_event('find_no_issues_duo_code_review_after_review')
          else
            publish_draft_notes(draft_notes, message)
          end

          ServiceResponse.success
        rescue StandardError => error
          track_review_merge_request_exception(error)
          track_review_merge_request_event('encounter_duo_code_review_error_during_review')
          message = ::Gitlab::Duo::CodeReview::Messages.generic_error
          update_progress_note(message, with_todo: true)
          error(message)
        ensure
          update_review_state('reviewed')
          progress_note&.destroy
        end

        private

        attr_reader :user, :merge_request, :review_output, :progress_note, :workflow_id

        def project
          merge_request.project
        end
        strong_memoize_attr :project

        def review_bot
          Users::Internal.in_organization(project.organization_id).duo_code_review_bot
        end
        strong_memoize_attr :review_bot

        def update_progress_note(note, with_todo: false)
          return unless progress_note

          TodoService.new.new_review(merge_request, review_bot) if with_todo

          ::Notes::CreateService.new(
            project,
            review_bot,
            noteable: merge_request,
            note: note,
            workflow_id: workflow_id
          ).execute
        end

        def update_review_state(state)
          return unless merge_request

          ::MergeRequests::UpdateReviewerStateService.new(
            project: project,
            current_user: review_bot
          ).execute(merge_request, state)
        end

        def publish_draft_notes(draft_notes, summary)
          return unless Ability.allowed?(user, :create_note, merge_request)
          return if draft_notes.empty?

          DraftNote.bulk_insert_and_keep_commits!(draft_notes, batch_size: 20)

          update_progress_note(summary)

          track_review_merge_request_event(
            'post_comment_duo_code_review_on_diff',
            additional_properties: {
              value: draft_notes.size
            }
          )

          # We set `executing_user` as the user who executed the duo code
          # review action as we only want to publish duo code review bot's review
          # if the executing user is allowed to create notes on the MR.
          DraftNotes::PublishService
            .new(
              merge_request,
              review_bot
            ).execute(executing_user: user)
        end

        def log_metrics(metrics)
          return unless Feature.enabled?(:duo_code_review_response_logging, user)

          log_review_merge_request_event(
            message: "LLM response comments metrics",
            event: "review_merge_request_llm_response_comments",
            merge_request_id: merge_request.id,
            total_comments: metrics.total_comments,
            comments_with_valid_path: metrics.comments_with_valid_path,
            comments_with_valid_line: metrics.comments_with_valid_line,
            comments_with_custom_instructions: metrics.comments_with_custom_instructions,
            comments_line_matched_by_content: metrics.comments_line_matched_by_content,
            draft_notes_created: metrics.draft_notes_created
          )
        end
      end
    end
  end
end
