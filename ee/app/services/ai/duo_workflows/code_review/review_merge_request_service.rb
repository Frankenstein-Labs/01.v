# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module CodeReview
      class ReviewMergeRequestService
        include Gitlab::Utils::StrongMemoize
        include Gitlab::InternalEventsTracking

        CouldNotStartWorkflowError = Class.new(StandardError)

        TIMEOUT_DURATION = 30.minutes

        # We use :duo_agent_platform as the unit primitive because this Duo Code Review feature
        # is now part of the Duo Agent Platform offering. All customers with Duo Agent Platform
        # access (via Duo Core and Duo Pro add-ons) should be able to use this feature.
        # Previously, this used :review_merge_request as a separate unit primitive with different licensing.
        #
        # Note: Duo Enterprise customers will continue using the legacy Duo Code Review for the time being.
        # More context: https://gitlab.com/gitlab-org/gitlab/-/issues/579921
        UNIT_PRIMITIVE = :duo_agent_platform

        def initialize(user:, merge_request:)
          @user = user
          @merge_request = merge_request
        end

        def execute
          track_review_request_event

          update_review_state('review_started')

          result = start_workflow

          if result.error?
            track_exception(CouldNotStartWorkflowError.new(result.message), result.reason)
            cleanup_failed_review(failure_message_for_result(result))
          else
            workflow = result.payload[:workflow]
            progress_note = create_progress_note(workflow)

            # Schedule timeout cleanup job for 30 minutes from now in case workflow fails midway
            ::Ai::DuoWorkflows::CodeReview::TimeoutWorker.perform_in(TIMEOUT_DURATION, merge_request.id)
          end

          result
        rescue StandardError => error
          track_exception(error, :exception)
          cleanup_failed_review(::Gitlab::Duo::CodeReview::Messages.exception_when_starting_workflow_error)
          progress_note&.destroy
          ServiceResponse.error(message: error.message)
        end

        private

        attr_reader :user, :merge_request

        def start_workflow
          ::Ai::DuoWorkflows::CreateAndStartWorkflowService.new(
            container: project,
            resource: merge_request,
            current_user: user,
            workflow_definition: ::Ai::Catalog::FoundationalFlow['code_review/v1'],
            goal: merge_request.iid,
            source_branch: merge_request.source_branch
          ).execute
        end

        def cleanup_failed_review(message)
          create_failure_note(message)
          update_review_state('reviewed')
        end

        def failure_message_for_result(result)
          failure_message_resolver.resolve(result.reason)
        end

        def create_progress_note(workflow)
          ::SystemNotes::MergeRequestsService.new(
            noteable: merge_request,
            container: project,
            author: review_bot
          ).duo_code_review_started(workflow)
        end

        def track_review_request_event
          event_name = if user.id == merge_request.author_id
                         'request_review_duo_code_review_on_mr_by_author'
                       else
                         'request_review_duo_code_review_on_mr_by_non_author'
                       end

          track_internal_event(
            event_name,
            user: user,
            project: project,
            additional_properties: { property: merge_request.id.to_s }
          )
        end

        def create_failure_note(message)
          todo_service.new_review(merge_request, review_bot)

          ::Notes::CreateService.new(
            project,
            review_bot,
            noteable: merge_request,
            note: message
          ).execute
        end

        def update_review_state(state)
          ::MergeRequests::UpdateReviewerStateService
            .new(project: project, current_user: review_bot)
            .execute(merge_request, state)
        end

        def track_exception(error, reason, context = {})
          return if failure_message_resolver.known_reason?(reason)

          Gitlab::ErrorTracking.track_exception(
            error,
            {
              reason: reason.to_s,
              unit_primitive: UNIT_PRIMITIVE.to_s,
              merge_request_id: merge_request.id,
              merge_request_iid: merge_request.iid,
              project_id: project.id,
              user_id: user.id
            }.merge(context)
          )
        end

        def failure_message_resolver
          FailureMessageResolver.new(user: user)
        end
        strong_memoize_attr :failure_message_resolver

        def project
          merge_request.project
        end
        strong_memoize_attr :project

        def review_bot
          Users::Internal.in_organization(project.organization_id).duo_code_review_bot
        end
        strong_memoize_attr :review_bot

        def todo_service
          TodoService.new
        end
        strong_memoize_attr :todo_service
      end
    end
  end
end
