# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class FailStuckWorkflowsWorker
      include ::ApplicationWorker
      include ::CronjobQueue

      idempotent!
      worker_resource_boundary :cpu
      urgency :low
      feature_category :duo_agent_platform
      data_consistency :sticky

      def perform
        ::Ai::DuoWorkflows::CleanStuckWorkflowsService.new.execute
      end
    end
  end
end
