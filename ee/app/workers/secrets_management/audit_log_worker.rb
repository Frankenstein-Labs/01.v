# frozen_string_literal: true

module SecretsManagement
  class AuditLogWorker
    include ApplicationWorker

    data_consistency :delayed
    feature_category :secrets_management
    urgency :low
    # Identical payloads can only come from OpenBao re-sending the same audit
    # line, so deduplicating on the raw JSON argument is safe and desirable.
    deduplicate :until_executed
    idempotent!
    defer_on_database_health_signal :gitlab_main_org, [:audit_events, :project_audit_events, :group_audit_events],
      1.minute

    # Comfortably outlives both the retry schedule and OpenBao re-sends of
    # the same audit line, without accumulating a key per secrets read for
    # longer than needed.
    PROCESSED_MARKER_TTL = 6.hours

    def perform(raw_audit_log_json)
      audit_log = AuditLog.new(raw_audit_log_json)
      write_audit_log(audit_log)

      begin
        BillableEvents::SecretsReadEmitter.emit!(audit_log)
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e)
      end
    end

    private

    # Sidekiq delivers at least once: a retry or a crash-recovery redelivery
    # can re-run a job whose audit write already committed, and the audit
    # tables have no natural-key guard against a second insert. A Redis
    # marker keyed on OpenBao's request id - set only after a successful
    # write - makes the write effectively-once. Billing needs no marker
    # here: the emitter sends its own request-id-based idempotency key
    # downstream, so re-running it is safe.
    def write_audit_log(audit_log)
      marker = processed_marker_key(audit_log)
      return audit_log.log! unless marker

      IdempotencyCache.ensure_idempotency(marker, PROCESSED_MARKER_TTL) do
        audit_log.log!
      end
    end

    def processed_marker_key(audit_log)
      request_id = audit_log.parsed_json.dig('request', 'id')
      return if request_id.blank?

      "secrets_management:audit_log_worker:#{request_id}"
    end
  end
end
