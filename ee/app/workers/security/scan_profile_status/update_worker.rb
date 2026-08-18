# frozen_string_literal: true

module Security
  module ScanProfileStatus
    class UpdateWorker
      include ApplicationWorker
      include Gitlab::ExclusiveLeaseHelpers

      # The worker uses a read-then-write counter pattern (consecutive_failure_count + 1),
      # so the new value depends on the previous run's commit being visible. :sticky cannot
      # guarantee this because the dedup scope (pipeline_id) differs from the lease scope
      # (project_id), meaning the enqueue LSN for a subsequent worker may be recorded before
      # the previous worker commits its update. :always ensures reads always hit the primary.
      # See: https://gitlab.com/gitlab-org/gitlab/-/issues/598530 for the follow-up to move
      # the arithmetic into SQL so we can drop back to :sticky.
      data_consistency :always # rubocop:disable SidekiqLoadBalancing/WorkerDataConsistency -- see comment above
      feature_category :security_testing_configuration
      idempotent!
      deduplicate :until_executed
      urgency :low
      defer_on_database_health_signal :gitlab_sec, [:security_scan_profile_project_statuses]

      LEASE_TTL = 5.minutes
      LEASE_TRY_AFTER = 2.seconds
      LEASE_RETRIES = 2
      RETRY_IN_IF_LOCKED = 10.seconds

      def perform(pipeline_id)
        pipeline = Ci::Pipeline.find_by_id(pipeline_id)
        return unless pipeline&.default_branch?

        perform_with_lock(pipeline)
      end

      private

      def perform_with_lock(pipeline)
        in_lock(lease_key(pipeline.project_id), ttl: LEASE_TTL, sleep_sec: LEASE_TRY_AFTER, retries: LEASE_RETRIES) do
          UpdateService.new(pipeline).execute
        end
      rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError
        self.class.perform_in(RETRY_IN_IF_LOCKED, pipeline.id)
      end

      def lease_key(project_id)
        "security:scan_profile_status_update_worker:#{project_id}"
      end
    end
  end
end
