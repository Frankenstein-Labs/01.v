# frozen_string_literal: true

module Vulnerabilities
  module WorkflowTrackable
    def perform(*args)
      item_id, execution_id = args

      finding = finding_from_args(item_id)
      return super unless finding

      execution = execution_from_args(finding, execution_id)
      return super unless execution

      if execution.cancel_requested?
        execution.mark_cancelled!([finding.uuid])
        cancel_pending_findings(execution)

        return
      end

      result = super

      _transition, next_item_ids = execution.mark_completed!([finding.uuid])

      enqueue_items(execution, next_item_ids)

      result
    end

    def handle_retry_exhaustion(job)
      item_id, execution_id = job['args']
      return unless execution_id

      finding = finding_from_args(item_id)
      return unless finding

      execution = execution_from_args(finding, execution_id)
      return unless execution

      _transition, next_item_ids = execution.mark_failed!([finding.uuid])

      enqueue_items(execution, next_item_ids)
    end

    private

    def cancel_pending_findings(execution)
      execution.pending_ids_by_stage.each do |stage_order, item_ids|
        item_ids.each_slice(execution.batch_size) do |batch|
          execution.mark_cancelled!(batch, stage_order: stage_order)
        end
      end
    end

    def execution_from_args(finding, execution_id)
      return unless execution_id
      return unless Feature.enabled?(:bulk_vulnerabilities_duo_workflow_api, finding.project)

      ::Vulnerabilities::BulkDuoWorkflow::ExecutionState.fetch(
        execution_id: execution_id,
        project_id: finding.project_id,
        workflow: self.class::WORKFLOW_DEFINITION
      )
    end

    def finding_from_args(...)
      return super if defined?(super)

      raise NotImplementedError, "#{self.class} must implement #finding_from_args"
    end

    def enqueue_items(execution, item_ids)
      return if item_ids.blank?

      config = ::Vulnerabilities::BulkDuoWorkflowRegistry.fetch(execution.workflow)

      config[:resolve_ids].call(item_ids).each do |id|
        config[:worker].perform_async(id, execution.execution_id)
      end
    end
  end
end
