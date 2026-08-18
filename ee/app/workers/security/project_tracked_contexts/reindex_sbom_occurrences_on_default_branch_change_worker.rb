# frozen_string_literal: true

module Security
  module ProjectTrackedContexts
    # We have a field in the sbom_occurrence_refs index called `is_default`, which is a denormalization
    # of project_security_tracked_contexts.is_default. This allows us to efficiently search
    # for the SBOM occurrences on the default branch. The purpose of this worker is to
    # re-index all of the SBOM occurrences on a project when the default branch changes,
    # updating the denormalized field to the correct value.
    class ReindexSbomOccurrencesOnDefaultBranchChangeWorker
      include Gitlab::EventStore::Subscriber

      BATCH_SIZE = 100

      data_consistency :delayed
      urgency :low
      idempotent!
      defer_on_database_health_signal :gitlab_sec, [:sbom_occurrence_refs], 1.minute

      feature_category :dependency_management

      def handle_event(event)
        project = Project.find_by_id(event.data[:container_id])
        return unless project

        ::Sbom::OccurrenceRef.by_project(project.id).each_batch(of: BATCH_SIZE) do |batch|
          ::Sbom::BulkEsOperationService.new(batch).execute
        end
      end
    end
  end
end
