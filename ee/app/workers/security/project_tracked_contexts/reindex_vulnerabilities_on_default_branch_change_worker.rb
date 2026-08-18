# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    # We have a field in the vulnerabilities index called `is_default`, which is a denormalization
    # of project_security_tracked_contexts.is_default. This allows us to efficiently search
    # for the vulnerabilities on the default branch. The purpose of this worker is to
    # re-index all of the vulnerabilities on a project when the default branch changes,
    # updating the denormalized field to the correct value.
    class ReindexVulnerabilitiesOnDefaultBranchChangeWorker
      include Gitlab::EventStore::Subscriber

      BATCH_SIZE = 100

      data_consistency :delayed
      urgency :low
      idempotent!
      defer_on_database_health_signal :gitlab_sec, [:vulnerability_reads], 1.minute

      feature_category :vulnerability_management

      def handle_event(event)
        project = Project.find_by_id(event.data[:container_id])
        return unless project

        # Covered by composite index on (project_id, vulnerability_id)
        ::Vulnerabilities::Read.by_projects(project).each_batch(of: BATCH_SIZE, column: :vulnerability_id) do |batch|
          ::Vulnerabilities::BulkEsOperationService.new(batch).execute
        end
      end
    end
  end
end
