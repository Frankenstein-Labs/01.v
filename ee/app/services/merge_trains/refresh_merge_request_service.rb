# frozen_string_literal: true

module MergeTrains
  class RefreshMergeRequestService < BaseService
    include Gitlab::Utils::StrongMemoize

    ProcessError = Class.new(StandardError)
    ConcurrencyError = Class.new(StandardError)
    UnlockError = Class.new(StandardError)

    attr_reader :merge_request

    ##
    # Arguments:
    # merge_request ... The merge request to be refreshed
    def execute(merge_request)
      @merge_request = merge_request

      # Unstick mechanism for stuck merge requests
      if merge_train_car.merging?
        if timed_out?
          unstick!
        else
          raise ConcurrencyError, 'concurrency error'
        end
      else
        validate!
        pipeline_created = create_pipeline! if merge_train_car.requires_new_pipeline? || require_recreate?

        log_running_security_scans

        merge! if merge_train_car.merge_ready_pipeline?
        success(pipeline_created: pipeline_created.present?)
      end
    rescue ProcessError => e
      abort(e)
    rescue ConcurrencyError
      # We're not going to abort here, but we want the worker to crash to be picked up again.
      # We don't want the car to get destroyed but rather unlocked, when the worker gets picked up again, if we run into the given timeout,
      # or an mr could not be unlocked (which should never happen).
      raise
    rescue UnlockError => e
      abort(e)
      merge_request.add_to_locked_set
    rescue StandardError => e
      Gitlab::ErrorTracking.track_exception(
        e,
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        project_id: merge_request.target_project_id
      )

      abort(
        ProcessError.new(
          "unexpected error occurred - correlation id: #{Labkit::Correlation::CorrelationId.current_or_new_id}"
        )
      )
    end

    private

    def handle_silently_merged_stuck_car
      merge_request.mark_as_merged!
      merge_train_car.finish_merge!
      log_unstick_action('reconciled_silently_merged')
    rescue StateMachines::InvalidTransition, ActiveRecord::RecordInvalid => e
      Gitlab::ErrorTracking.track_exception(
        e,
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        project_id: merge_request.target_project_id,
        handler: 'handle_silently_merged_stuck_car'
      )

      handle_locked_stuck_car
    end

    def validate!
      unless project.merge_trains_enabled?
        raise ProcessError, 'project disabled merge trains'
      end

      unless merge_request.on_train?
        raise ProcessError, 'merge request is not on a merge train'
      end

      validate_merge_request!

      unless merge_train_car.previous_ref_sha.present?
        raise ProcessError, "the previous ref does not exist. [Learn more](#{learn_more_url})."
      end

      if merge_train_car.pipeline_not_succeeded?
        raise ProcessError, "the pipeline did not succeed. [Learn more](#{learn_more_url})."
      end
    end

    def unstick!
      if merge_request.merged_in_repository? && (merge_request.locked? || merge_request.opened?)
        handle_silently_merged_stuck_car
      elsif merge_request.merged?
        handle_merged_stuck_car
      elsif merge_request.locked?
        handle_locked_stuck_car
      elsif merge_request.open?
        handle_open_stuck_car
      elsif merge_request.closed?
        handle_closed_stuck_car
      else
        # Should be unreachable. Defensive guard against future changes
        handle_unexpected_merge_request_state
      end

      success(pipeline_created: false)
    end

    # This should never be called.
    # If this happens nevertheless, something has changed with the state machine of the merge request e.g.
    # a new state has been added.
    def handle_unexpected_merge_request_state
      Gitlab::ErrorTracking.track_exception(
        StandardError.new("Unexpected merge request state during unstick: #{merge_request.state}"),
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        project_id: merge_request.target_project_id,
        merge_request_state: merge_request.state
      )

      raise ProcessError, "train car got stuck in merging. [Learn more](#{learn_more_url})"
    end

    def handle_merged_stuck_car
      merge_train_car.finish_merge!
      log_unstick_action('finish_merge')
    end

    def handle_locked_stuck_car
      if merge_request.unlock_mr
        log_unstick_action('abort_merge_locked')
        raise ProcessError, "train car got stuck in merging. [Learn more](#{learn_more_url})"
      else
        # In very special, seldom cases, we cannot unlock a stuck MR due to validation errors.
        # In that cases, we destroy the car and hand over to the already existing unlock service.
        log_unstick_action('forced_unlock', merge_request.errors.full_messages)
        raise UnlockError, "train car got stuck in merging. [Learn more](#{learn_more_url})"
      end
    end

    def handle_open_stuck_car
      log_unstick_action('abort_merge_open')
      raise ProcessError, "train car got stuck in merging. [Learn more](#{learn_more_url})"
    end

    def handle_closed_stuck_car
      if merge_train_car.destroy
        log_unstick_action('destroy_closed')
      else
        log_unstick_action('destroy_failed')
      end
    end

    def timed_out?
      merge_train_car.updated_at < MergeTrains::Car::STUCK_AFTER.ago
    end

    def log_unstick_action(action, errors = nil)
      Gitlab::AppLogger.warn(
        message: 'Unstuck stuck merge train merge',
        action: action,
        merge_request_id: merge_request.id,
        merge_request_iid: merge_request.iid,
        project_id: merge_request.target_project_id,
        errors: errors
      )
    end

    def validate_merge_request!
      unless merge_request.open?
        raise ProcessError, "the merge request is closed. [Learn more](#{learn_more_url})."
      end

      if merge_request.broken?
        raise ProcessError, "the merge request is broken. [Learn more](#{learn_more_url})."
      end

      if merge_request.draft?
        raise ProcessError, "the merge request is marked as draft. [Learn more](#{learn_more_url})."
      end

      unless merge_request.auto_merge_enabled?
        raise ProcessError, 'the merge request is not set to auto-merge'
      end
    end

    def learn_more_url
      Rails.application.routes.url_helpers.help_page_url(
        'ci/pipelines/merge_trains.md',
        anchor: 'merge-request-dropped-from-the-merge-train'
      )
    end

    def merge_from_train_ref?
      unless project.ff_merge_must_be_possible? ||
          Feature.enabled?(:merge_trains_use_train_ref_for_standard_merges, project)
        return false
      end

      # The FromTrainRef strategy does not yet support restartless merges
      # (skip_merged). A skip-merge changes the target branch, making the
      # train ref no longer a valid fast-forward candidate.
      return false if project.merge_trains_skip_train_allowed?

      mergeable_sha_and_message?(merge_train_car)
    end

    def create_mergeable_train_ref?
      # The two checks below ensure that by construction, we can safely
      # fast-forward merge from any train ref satisfying
      # #mergeable_from_train_ref?
      #
      # (1) Base case: If we're the first car, then the train ref will be based
      # on the target branch, and is trivially mergeable. We use #prev instead
      # of #first_active_car? to guard against an unlikely edge case where the car
      # becomes the first car in between those two checks.
      prev = merge_train_car.prev_active
      return true if prev.nil?

      # (2) Recursive case: The previous MR has not been merged, so we check
      # whether it was constructed with a mergeable train ref.
      mergeable_sha_and_message?(prev)
    end

    def mergeable_sha_and_message?(car)
      # The commit message check guards against a very unlikely edge case in
      # which a merge train created by MergeTrains::CreateRefService has been
      # running since before standard merge commits were first enabled, and no
      # merge has occurred.
      #
      # The train_ref commit_sha check is for mixed rollout scenarios, such as
      # when the various feature flags are toggled, or when old code is running
      # concurrently with new code, or when a train exists from before the
      # instance was updated.
      sha = car.pipeline&.sha
      project.commit(sha)&.message != MergeTrains::MergeCommitMessage.legacy_value(merge_request, car.previous_ref) &&
        sha == car&.merge_request&.merge_params&.dig('train_ref', 'commit_sha')
    end

    def create_pipeline!
      result = MergeTrains::CreatePipelineService.new(merge_train_car.project, merge_train_car.user)
        .execute(merge_train_car.merge_request, merge_train_car.previous_ref, create_mergeable_train_ref?)

      raise ProcessError, result[:message] unless result[:status] == :success

      pipeline = result[:pipeline]
      cancel_pipeline!(merge_train_car.pipeline, pipeline)
      merge_train_car.refresh_pipeline!(pipeline.id)

      pipeline
    end

    def cancel_pipeline!(pipeline, new_pipeline)
      ::Ci::CancelPipelineService
        .new(pipeline: pipeline, current_user: nil, auto_canceled_by_pipeline: new_pipeline)
        .force_execute
    rescue ActiveRecord::StaleObjectError
      # Often the pipeline has already been canceled by the auto-cancellation
      # mechanism when new pipelines for the same ref are created.
      # In this case, we can ignore the exception as it's already canceled.
    end

    def merge!
      merge_train_car.start_merge!

      merge_options = { skip_discussions_check: true, check_mergeability_retry_lease: true }
      merge_options[:merge_strategy] = MergeRequests::MergeStrategies::FromTrainRef if merge_from_train_ref?

      # Marks this as the merge train's own merge so it is exempt from merge train enforcement.
      merge_params = merge_request.merge_params.with_indifferent_access.merge(merging_via_merge_train: true)

      MergeRequests::MergeService.new(project: project, current_user: merge_user, params: merge_params)
        .execute(merge_request, **merge_options)

      raise ProcessError, "failed to merge. #{merge_request.merge_error}" unless merge_request.merged?

      merge_train_car.finish_merge!
    end

    def merge_train_car
      merge_request.merge_train_car
    end

    def merge_user
      merge_request.merge_user
    end

    def require_recreate?
      params[:require_recreate]
    end

    def abort(error)
      AutoMerge::MergeTrainService.new(project, merge_train_car.user)
        .abort(merge_request, error.message, process_next: false)

      error(error.message)
    end

    def log_running_security_scans
      Gitlab::AppLogger.warn("Security scans running") if merge_request.running_scan_result_policy_violations.any?
    end
  end
end
