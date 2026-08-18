# frozen_string_literal: true

module SecretsManagement
  module BillableEvents
    class SecretsReadEmitter
      EVENT_TYPE = 'secrets_read'
      UNIT_OF_MEASURE = 'request'
      # Per-CDot-call budget for the synchronous fallback path (the
      # `secrets_manager_async_audit_logs` flag disabled), where OpenBao
      # waits on the audit callback: two sequential calls must stay under
      # ~500ms worst case. Async processing (the flag enabled) runs this in
      # AuditLogWorker where latency is not critical; once the sync path is
      # removed (https://gitlab.com/gitlab-org/gitlab/-/work_items/606142),
      # this budget can be relaxed or dropped.
      ENTITLEMENT_TIMEOUT_SECONDS = 0.25
      BILLABLE_EVENT_TYPES = %i[
        secrets_manager_read_project_secret
        secrets_manager_read_group_secret
      ].freeze

      def self.emit!(audit_log)
        new(audit_log).emit!
      end

      def initialize(audit_log)
        @audit_log = audit_log
      end

      def emit!
        return unless feature_enabled?
        return unless billable?
        return unless billing_namespace

        ::Gitlab::BillingEvents::Client.track_billing_event(
          event_type: EVENT_TYPE,
          category: self.class.name,
          unit_of_measure: UNIT_OF_MEASURE,
          quantity: 1,
          namespace: billing_namespace,
          project: audit_log.project,
          user: audit_log.author,
          idempotency_key: idempotency_key,
          timestamp: event_timestamp,
          metadata: metadata
        )
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e, audit_log_event_type: audit_log&.event_type)
        nil
      end

      private

      attr_reader :audit_log

      def feature_enabled?
        ::Feature.enabled?(
          :secrets_manager_emit_secret_read_events,
          audit_log.project || audit_log.group || :instance,
          type: :gitlab_com_derisk
        )
      end

      def billable?
        return false if request_log?
        return false unless BILLABLE_EVENT_TYPES.include?(audit_log.event_type&.to_sym)
        return false unless read_succeeded?

        true
      end

      def request_log?
        audit_log.parsed_json['type'] == 'request'
      end

      def read_succeeded?
        audit_log.parsed_json.dig('auth', 'policy_results', 'allowed') == true
      end

      def billing_namespace
        audit_log.project&.namespace || audit_log.group
      end

      def idempotency_key
        return unless openbao_request_id

        "#{EVENT_TYPE}:#{openbao_request_id}"
      end

      def event_timestamp
        ::Time.zone.parse(audit_log.parsed_json['time'].to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def openbao_request_id
        audit_log.parsed_json.dig('request', 'id')
      end

      def openbao_entity_id
        audit_log.parsed_json.dig('auth', 'entity_id')
      end

      def metadata
        {
          pipeline_id: audit_log.pipeline_id,
          job_id: audit_log.job_id,
          mount_type: audit_log.parsed_json.dig('request', 'mount_type'),
          audit_request_id: openbao_request_id,
          openbao_entity_id: openbao_entity_id,
          entitlement_state: entitlement&.state&.to_s,
          blocked_reason: entitlement&.blocked_reason&.to_s
        }.compact
      end

      # Emitted unconditionally; CDot rates on (event_type, entitlement_state, blocked_reason) downstream.
      # Fail-open: on resolution failure the entitlement keys are omitted, not stamped `ineligible`.
      def entitlement
        return @entitlement if defined?(@entitlement)

        @entitlement = Entitlement.for!(
          Entitlement.root_namespace_for(billing_namespace),
          http_timeout: ENTITLEMENT_TIMEOUT_SECONDS
        )
      rescue StandardError => e
        ::Gitlab::ErrorTracking.log_exception(e, audit_log_event_type: audit_log&.event_type)
        @entitlement = nil
      end
    end
  end
end
