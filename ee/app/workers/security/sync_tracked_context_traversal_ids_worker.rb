# frozen_string_literal: true

module Security
  class SyncTrackedContextTraversalIdsWorker
    include ApplicationWorker

    idempotent!
    deduplicate :until_executing, including_scheduled: true
    # rubocop: disable SidekiqLoadBalancing/WorkerDataConsistency -- Needs fresh traversal_ids from primary database
    data_consistency :always
    # rubocop: enable SidekiqLoadBalancing/WorkerDataConsistency

    feature_category :vulnerability_management

    def perform(project_id)
      ::Security::ProjectTrackedContexts::SyncTraversalIdsService.execute(project_id)
    end
  end
end
