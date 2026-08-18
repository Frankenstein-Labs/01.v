# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class GenerateWorkflowSummaryWorker
      include ApplicationWorker

      idempotent!
      feature_category :duo_agent_platform
      data_consistency :sticky

      def perform(workflow_id)
        workflow = ::Ai::DuoWorkflows::Workflow.find_by_id(workflow_id)
        return unless workflow

        summary = SummarizeWorkflowService.new(workflow: workflow).execute
        workflow.update!(summary: summary.truncate(1024)) if summary.present?
      end
    end
  end
end
