# frozen_string_literal: true

module Ai
  module DuoWorkflows
    module Concerns
      module WorkloadMetrics
        extend ActiveSupport::Concern
        include ::Gitlab::InternalEventsTracking

        private

        def track_workload_completion_metrics(workflow, pipeline:, build:)
          return unless workflow && pipeline

          failure_reason = build&.failure_reason if build&.failed?

          track_internal_event(
            'duo_workflow_workload_completed',
            user: workflow.user,
            project: workflow.project,
            additional_properties: {
              label: pipeline.status,
              property: failure_reason,
              value: pipeline.duration,
              workflow_id: workflow.id.to_s,
              workflow_definition: workflow.workflow_definition
            }.compact
          )

          Gitlab::AppLogger.info(
            message: 'duo_workflow_workload_completed',
            pipeline_id: pipeline.id,
            pipeline_status: pipeline.status,
            failure_reason: failure_reason,
            pipeline_duration: pipeline.duration,
            workflow_id: workflow.id,
            workflow_definition: workflow.workflow_definition,
            project_id: workflow.project&.id,
            runner_id: build&.runner_id
          )
        end
      end
    end
  end
end
