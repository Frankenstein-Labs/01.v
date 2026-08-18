# frozen_string_literal: true

module Ai
  module RepositoryXray
    # This worker can be called multiple times simultaneously but only one can run at a time per project.
    # This is further enforced by an exclusive lease guard in `Ai::RepositoryXray::ScanDependenciesService`.
    class ScanDependenciesWorker
      include ApplicationWorker

      feature_category :code_suggestions

      data_consistency :sticky
      urgency :low
      idempotent!

      deduplicate :until_executed, if_deduplicated: :reschedule_once,
        ttl: Ai::RepositoryXray::ScanDependenciesService::LEASE_TIMEOUT

      def perform(project_id)
        Project.find_by_id(project_id).try do |project|
          response = Ai::RepositoryXray::ScanDependenciesService.new(project).execute

          log_hash_metadata_on_done(
            status: response.status,
            message: response.message,
            **response.payload
          )
        end
      end
    end
  end
end
