# frozen_string_literal: true

module Vulnerabilities
  class ProcessGroupArchivedEventsWorker
    include Gitlab::EventStore::Subscriber

    idempotent!
    deduplicate :until_executing, including_scheduled: true
    data_consistency :always

    feature_category :vulnerability_management

    def handle_event(event)
      return unless event.data[:group_id]

      namespace_id = event.data[:group_id]

      cursor = { current_id: namespace_id, depth: [namespace_id] }
      iterator = Gitlab::Database::NamespaceEachBatch.new(namespace_class: Namespace, cursor: cursor)

      iterator.each_batch(of: 100) do |ids, _new_cursor|
        Project.in_namespace(ids).each_batch(of: 100) do |project_batch|
          bulk_schedule_vulnerability_reads_worker(project_batch)
          bulk_schedule_vulnerability_statistics_worker(project_batch)
        end
      end

      NamespaceStatistics::RecalculateNamespaceStatisticsWorker.perform_in(6.hours, namespace_id)
    end

    private

    def bulk_schedule_vulnerability_reads_worker(projects)
      Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityReadsWorker
        .bulk_perform_async_with_contexts(
          projects,
          arguments_proc: ->(project) { project.id },
          context_proc: ->(project) { { project: project } }
        )
    end

    def bulk_schedule_vulnerability_statistics_worker(projects)
      Vulnerabilities::UpdateArchivedAttributeOfVulnerabilityStatisticsWorker
        .bulk_perform_async_with_contexts(
          projects,
          arguments_proc: ->(project) { project.id },
          context_proc: ->(project) { { project: project } }
        )
    end
  end
end
