# frozen_string_literal: true

module AuditEvents
  module AiAuditEvents
    class Finder
      # rubocop:disable CodeReuse/Finder -- Dispatches to a PG- or ClickHouse-backed finder
      def initialize(workflow:)
        @workflow = workflow
      end

      def execute
        if ::Gitlab::ClickHouse.globally_enabled_for_analytics?
          ::AuditEvents::AiAuditEvents::ClickHouseFinder.new(workflow: @workflow).execute
        else
          ::AuditEvents::AiAuditEvents::PostgresqlFinder.new(workflow: @workflow).execute
        end
      end
      # rubocop:enable CodeReuse/Finder
    end
  end
end
