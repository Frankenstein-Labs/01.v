# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class SyncSessionArtifactWorker
      include ApplicationWorker

      idempotent!
      data_consistency :delayed
      feature_category :compliance_management
      urgency :low
      defer_on_database_health_signal :gitlab_main, [:duo_workflow_session_artifacts]

      def perform(workflow_id)
        workflow = Ai::DuoWorkflows::Workflow.find_by_id(workflow_id)
        return unless workflow

        Ai::DuoWorkflows::SessionArtifact.sync_from_workflow!(workflow)
      end
    end
  end
end
