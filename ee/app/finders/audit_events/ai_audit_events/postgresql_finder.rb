# frozen_string_literal: true

module AuditEvents
  module AiAuditEvents
    class PostgresqlFinder
      def initialize(workflow:)
        @workflow = workflow
      end

      def execute
        ::AuditEvents::AiAuditEvent.for_workflow(@workflow.id).recent_first
      end
    end
  end
end
