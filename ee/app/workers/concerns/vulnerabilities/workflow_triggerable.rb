# frozen_string_literal: true

module Vulnerabilities
  module WorkflowTriggerable
    extend ActiveSupport::Concern

    private

    def resolve_workflow_user(vulnerability, project)
      author = vulnerability.author

      return author if Ability.allowed?(author, :duo_workflow, project)

      Gitlab::AppLogger.info(
        message: 'Vulnerability author does not have duo_workflow permission',
        vulnerability_id: vulnerability.id,
        project_id: project.id,
        author_id: author&.id
      )

      nil
    end

    def log_no_eligible_user(vulnerability, project)
      Gitlab::AppLogger.error(
        message: 'No eligible user found for vulnerability workflow, ' \
          'author lacks duo_workflow permission',
        vulnerability_id: vulnerability.id,
        project_id: project.id
      )
    end

    def log_service_account_not_found(vulnerability, consumer, workflow_name)
      Gitlab::AppLogger.error(
        message: "Service account not found for #{workflow_name}, " \
          'the service account may have been deleted',
        vulnerability_id: vulnerability.id,
        project_id: vulnerability.project_id,
        consumer_id: consumer.id,
        workflow_definition: self.class::WORKFLOW_DEFINITION
      )
    end
  end
end
