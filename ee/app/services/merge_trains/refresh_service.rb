# frozen_string_literal: true

module MergeTrains
  # This class is to refresh all merge requests on the merge train that
  # the given merge request belongs to.
  #
  # It performs a sequential update on all merge requests on the train.
  # Multiple runs with the same project and branch should not take place concurrently
  # NOTE: To prevent concurrent refreshes, two locking mechanisms are in place:
  # 1. `MergeTrains::RefreshWorker` deduplicates via `deduplicate :until_executed, if_deduplicated: :reschedule_once`
  # 2. This service holds an `ExclusiveLeaseGuard` (scoped to project + branch) and renews it per car,
  #    guarding against cases where a refresh outlives the worker's 10-minute deduplication TTL.
  class RefreshService
    include ::ExclusiveLeaseGuard

    DEFAULT_CONCURRENCY = 20
    LEASE_TIMEOUT = 10.minutes

    def initialize(target_project_id, target_branch)
      @target_project_id = target_project_id
      @target_branch = target_branch
    end

    def execute
      try_obtain_lease do
        require_next_recreate = false
        train = MergeTrains::Train.new(@target_project_id, @target_branch)

        train.refreshable_cars(limit: concurrency_limit).each do |car|
          break unless renew_lease!

          result = MergeTrains::RefreshMergeRequestService
            .new(car.target_project, car.user, require_recreate: require_next_recreate)
            .execute(car.merge_request)

          require_next_recreate = result[:status] == :error || result[:pipeline_created]
        end
      end
    end

    private

    def lease_timeout
      LEASE_TIMEOUT
    end

    def lease_key
      "merge_trains:refresh:#{@target_project_id}:#{@target_branch}"
    end

    def concurrency_limit
      project = Project.find_by_id(@target_project_id)
      return DEFAULT_CONCURRENCY unless project

      plan_limit = project.actual_limits.max_pipelines_per_merge_train
      project_limit = project.ci_cd_settings&.max_pipelines_per_merge_train

      if project_limit.present?
        [plan_limit, project_limit].min
      else
        plan_limit
      end
    end
  end
end
