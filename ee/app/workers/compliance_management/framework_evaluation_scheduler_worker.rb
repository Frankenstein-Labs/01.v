# frozen_string_literal: true

module ComplianceManagement
  class FrameworkEvaluationSchedulerWorker
    include ApplicationWorker
    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- does not require context

    version 1
    urgency :throttled
    data_consistency :sticky
    feature_category :compliance_management
    sidekiq_options retry: false
    idempotent!

    FRAMEWORK_BATCH_SIZE = 100
    PROJECT_BATCH_SIZE = 100

    def perform
      active_framework_ids = ComplianceManagement::Framework.active_framework_ids

      return if active_framework_ids.empty?

      active_framework_ids.each_slice(FRAMEWORK_BATCH_SIZE) do |framework_ids_batch|
        enqueue_batch_evaluations(framework_ids_batch)
      end
    end

    private

    def enqueue_batch_evaluations(framework_ids)
      framework_project_map = ComplianceManagement::ComplianceFramework::ProjectSettings
                                .framework_project_mappings(framework_ids)

      framework_project_map.each do |framework_id, project_ids|
        enqueue_framework_projects_evaluation(framework_id, project_ids)
      end
    end

    def enqueue_framework_projects_evaluation(framework_id, project_ids)
      project_ids.each_slice(PROJECT_BATCH_SIZE) do |project_ids_batch|
        ProjectComplianceEvaluatorWorker.perform_async(
          framework_id,
          project_ids_batch
        )
      end
    end
  end
end
