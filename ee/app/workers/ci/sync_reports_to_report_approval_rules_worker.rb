# frozen_string_literal: true

# Worker for syncing report_type approval_rules approvals_required
module Ci
  class SyncReportsToReportApprovalRulesWorker # rubocop:disable Scalability/IdempotentWorker
    include ApplicationWorker

    data_consistency :always

    sidekiq_options retry: 3
    include PipelineBackgroundQueue

    urgency :low
    worker_resource_boundary :unknown
    defer_on_database_health_signal :gitlab_main, [:approval_merge_request_rules], 1.minute

    def perform(pipeline_id)
      pipeline = Ci::Pipeline.find_by_id(pipeline_id)
      return unless pipeline

      ::Ci::SyncReportsToApprovalRulesService.new(pipeline).execute

      ::Ci::UpdateApprovalRulesForRelatedMrsWorker.perform_async(pipeline.id)
    end
  end
end
