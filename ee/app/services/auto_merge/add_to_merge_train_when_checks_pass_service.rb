# frozen_string_literal: true

# rubocop:disable Gitlab/BoundedContexts -- TODO refactor to use bounded context
module AutoMerge
  class AddToMergeTrainWhenChecksPassService < AutoMerge::BaseService
    extend Gitlab::Utils::Override

    def execute(merge_request)
      super do
        sha = merge_request.diff_head_pipeline&.sha || merge_request.diff_head_sha
        SystemNoteService.add_to_merge_train_when_checks_pass(merge_request, project, current_user, sha)
      end
    end

    def process(merge_request)
      logger.info("Processing Automerge - AMTWCP")

      return unless merge_request.mergeable?(skip_conflict_check: true, use_cache: false)

      logger.info("Merge request mergeable - AMTWCP")

      merge_train_service = AutoMerge::MergeTrainService.new(project, merge_request.merge_user)

      unless merge_train_service.available_for?(merge_request)
        abort_message = merge_train_service.availability_details(merge_request).abort_message

        return abort(merge_request, abort_message)
      end

      merge_train_service.execute(merge_request)
    end

    def cancel(merge_request)
      super do
        SystemNoteService.cancel_add_to_merge_train_when_checks_pass(merge_request, project, current_user)
      end
    end

    def abort(merge_request, reason)
      # If the merge request is already on a merge train, we need to destroy the car
      # i.e. If the target branch is deleted which causes an abort with this strategy,
      # after the pipeline succeeded and was added
      #
      if merge_request.merge_train_car
        AutoMerge::MergeTrainService.new(project, current_user).abort(merge_request, reason)
        # Before the pipeline checks pass and was added to the merge train
      else
        super do
          SystemNoteService.abort_add_to_merge_train_when_checks_pass(merge_request, project, current_user, reason)
        end
      end
    end

    # availability_details are responsible for validating whether the service is available_for a merge request and sets
    # an unavailable_reason if it is not
    override :availability_details
    def availability_details(merge_request)
      super do
        default_error = AutoMerge::AvailabilityCheck.error
        next default_error unless merge_request.has_ci_enabled?

        next default_error if merge_request.mergeable? && !merge_request.diff_head_pipeline_considered_in_progress?

        unless merge_request.project.merge_trains_enabled?
          next AutoMerge::AvailabilityCheck.error(unavailable_reason: :merge_trains_disabled)
        end

        AutoMerge::AvailabilityCheck.success
      end
    end
  end
end
# rubocop:enable Gitlab/BoundedContexts
