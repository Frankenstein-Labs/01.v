# frozen_string_literal: true

module Ai
  module DuoWorkflows
    # rubocop: disable Scalability/IdempotentWorker -- EventStore::Subscriber includes idempotent
    class UpdateWorkflowStatusEventWorker
      include Gitlab::EventStore::Subscriber
      include Concerns::WorkloadMetrics

      feature_category :duo_agent_platform
      data_consistency :delayed

      def handle_event(event)
        workload = Ci::Workloads::Workload.find_by_id(event.data[:workload_id])
        return unless workload

        workflow = workload.workflows.last
        return unless workflow

        action = event.data[:status].to_sym == :finished ? 'finish' : 'drop'

        pipeline = workload.pipeline
        build = pipeline.builds.last
        failure_reason = build.failure_reason if action == 'drop' && build&.failed?

        summary = "Error during Session: #{failure_reason}" if failure_reason

        if action == 'drop'
          result = UpdateWorkflowStatusService.new(workflow: workflow, status_event: action,
            current_user: workflow.user, summary: summary).execute
        end

        track_workload_completion_metrics(workflow, pipeline: pipeline, build: build)

        return unless failure_reason && result.success?

        GenerateWorkflowSummaryWorker.perform_async(workflow.id)
      end
    end
    # rubocop: enable Scalability/IdempotentWorker
  end
end
