# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class GenerateWorkflowTitleWorker
      include ApplicationWorker

      MAX_TITLE_LENGTH_IN_CHARS = 40

      idempotent!
      feature_category :duo_agent_platform
      data_consistency :sticky

      def perform(workflow_id)
        workflow = ::Ai::DuoWorkflows::Workflow.find_by_id(workflow_id)
        return unless workflow

        title = GenerateWorkflowTitleService.new(workflow: workflow).execute
        workflow.update!(title: title.truncate(MAX_TITLE_LENGTH_IN_CHARS)) if title.present?
      end
    end
  end
end
