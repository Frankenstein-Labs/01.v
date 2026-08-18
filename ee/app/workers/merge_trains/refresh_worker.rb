# frozen_string_literal: true

module MergeTrains
  class RefreshWorker
    include ApplicationWorker

    data_consistency :always

    sidekiq_options retry: 3

    queue_namespace :auto_merge
    feature_category :merge_trains
    worker_resource_boundary :cpu

    # Required, since `MergeTrains::RefreshService#execute` is concurrent-unsafe
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    idempotent!

    def perform(target_project_id, target_branch)
      Gitlab::QueryLimiting.disable!('https://gitlab.com/gitlab-org/gitlab/-/issues/464678', new_threshold: 202)

      ::MergeTrains::RefreshService
        .new(target_project_id, target_branch)
        .execute
    end
  end
end
