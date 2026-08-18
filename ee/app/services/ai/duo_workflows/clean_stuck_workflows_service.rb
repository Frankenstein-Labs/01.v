# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CleanStuckWorkflowsService
      include ::Services::ReturnServiceResponses
      include ::Gitlab::InternalEventsTracking

      EXPIRATION_IN_MINUTES = 30
      BATCH_LIMIT = 1000

      AUDIT_EVENT_NAME = 'duo_session_failed'
      AUDIT_EVENT_MESSAGE = 'Duo session failed: stuck session cleaned up after timeout'

      STUCK_WORKFLOWS_COUNTER = Gitlab::Metrics.counter(
        :gitlab_duo_workflow_stuck_workflows_cleaned_total,
        'Total number of stuck Duo Workflow sessions cleaned up, by original status and flow type'
      )

      def execute
        scope = Ai::DuoWorkflows::Workflow.with_status(:created, :running)
                  .stale_since(EXPIRATION_IN_MINUTES.minutes.ago)
                  .preload(:user, :project, :namespace) # rubocop:disable CodeReuse/ActiveRecord -- one-off preload for this cleanup loop, not worth a model scope
        iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: scope)

        iterator.each_batch(of: BATCH_LIMIT) do |workflows|
          workflows.to_a.each do |w|
            original_status = w.status_name
            track_fail(w, original_status) if w.drop
          end
        end

        success(:processed)
      end

      private

      def track_fail(workflow, original_status)
        STUCK_WORKFLOWS_COUNTER.increment(
          status: original_status.to_s,
          flow_type: workflow.workflow_definition.to_s
        )

        track_internal_event(
          "cleanup_stuck_agent_platform_session",
          user: workflow.user,
          project: workflow.project,
          namespace: workflow.namespace,
          additional_properties: {
            label: workflow.workflow_definition,
            value: workflow.id,
            property: "failed"
          }
        )

        audit_fail(workflow)
      end

      def audit_fail(workflow)
        audit_context = {
          name: AUDIT_EVENT_NAME,
          author: ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)'),
          scope: workflow.project || workflow.namespace,
          target: workflow,
          target_details: "#{workflow.workflow_definition} session #{workflow.id}",
          message: AUDIT_EVENT_MESSAGE
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e, workflow_id: workflow.id)
      end
    end
  end
end
