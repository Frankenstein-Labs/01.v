# frozen_string_literal: true

module AuditEvents
  module AiAuditEvents
    class Streamer
      def self.stream(ai_audit_event)
        new(ai_audit_event).execute
      end

      def initialize(ai_audit_event)
        @ai_audit_event = ai_audit_event
      end

      def execute
        return if ::Gitlab::SilentMode.enabled?
        return unless instance_streaming_enabled?

        ::AuditEvents::AiAuditEventStreamingWorker.perform_async(@ai_audit_event.streaming_json)
      end

      private

      def instance_streaming_enabled?
        return false unless organization

        !!::Ai::Setting.for_organization_read_only(organization).ai_audit_events_streaming_enabled
      end

      def organization
        ::Project.find_by_id(@ai_audit_event.project_id)&.organization ||
          ::Namespace.find_by_id(@ai_audit_event.namespace_id)&.organization
      end
    end
  end
end
