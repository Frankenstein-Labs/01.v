# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class IngestAuditEventsService
      include ::Gitlab::InternalEventsTracking
      include Gitlab::Utils::StrongMemoize

      MAX_EVENTS_PER_REQUEST = 500

      RESERVED_HUMAN_AUTHOR_KEYS = %w[human_author_id human_author_name human_author_username].freeze

      INGESTED_COUNTER = Gitlab::Metrics.counter(
        :gitlab_ai_audit_events_ingested_total,
        'AI audit events accepted for storage (counted pre-persistence; compare to stored/buffered to detect loss)'
      )

      DROPPED_COUNTER = Gitlab::Metrics.counter(
        :gitlab_ai_audit_events_dropped_total,
        'AI audit events dropped before persistence'
      )

      def initialize(workflow:, events:, current_user:)
        @workflow = workflow
        @events = Array(events)
        @current_user = current_user
      end

      def execute
        if @events.size > MAX_EVENTS_PER_REQUEST
          return ServiceResponse.error(
            message: "Batch size #{@events.size} exceeds maximum of #{MAX_EVENTS_PER_REQUEST}",
            reason: :bad_request
          )
        end

        audit_events = build_audit_events

        if audit_events.any?
          ::Ai::DuoWorkflows::ProcessAuditEventsWorker.perform_async(
            audit_events.map(&:attributes)
          )
          track_ingest_batch(audit_events)
        end

        payload = { status: 'accepted', count: audit_events.size }
        payload[:dropped_unknown_event_types] = unknown_event_names if unknown_event_names.any?

        ServiceResponse.success(payload: payload)
      end

      private

      def unknown_event_names
        @unknown_event_names ||= begin
          payload_event_names = @events.filter_map { |event| event[:type].presence }.uniq
          (payload_event_names - ::AuditEvents::AiAuditEvent::ALLOWED_EVENT_NAMES).sort
        end
      end

      def build_audit_events
        # Events are relayed by the executor from a GCP NAT address, so the payload's ip_address
        # is never the user's. Attribute to the user's last sign-in IP instead - the closest
        # durable user IP available at ingest - matching AuditEvents::BuildService's fallback.
        user_ip = @current_user.current_sign_in_ip

        @events.filter_map do |event|
          if reject_event?(event)
            DROPPED_COUNTER.increment(reason: :malformed)
            next
          end

          unless ::AuditEvents::AiAuditEvent::ALLOWED_EVENT_NAMES.include?(event[:type])
            DROPPED_COUNTER.increment(reason: :unknown_event)
            next
          end

          audit_event = ::AuditEvents::AiAuditEvent.new(
            cloud_event_id: event[:id],
            event_name: event[:type],
            created_at: event[:time],
            author_id: author.id,
            project_id: @workflow.project_id,
            namespace_id: @workflow.namespace_id,
            ip_address: user_ip,
            workflow_id: @workflow.id,
            details: event_details(event, user_ip)
          )

          INGESTED_COUNTER.increment(event_name: event[:type])

          audit_event
        end
      end

      # The reserved keys are stripped from the relayed payload so they can only
      # ever carry the server-side resolved human, never caller-supplied values.
      def event_details(event, user_ip)
        (event[:data] || {}).stringify_keys
          .except(*RESERVED_HUMAN_AUTHOR_KEYS)
          .merge('ip_address' => user_ip&.to_s)
          .merge(human_author_details)
      end

      # Key names must match the human_author_* details convention that
      # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/240418 introduces
      # for standard audit events, so streaming consumers see one shape.
      def human_author_details
        return {} unless composite_identity?

        {
          'human_author_id' => @current_user.id,
          'human_author_name' => @current_user.name,
          'human_author_username' => @current_user.username
        }
      end
      strong_memoize_attr :human_author_details

      def composite_identity?
        author != @current_user
      end

      # For composite-identity tokens auth_finders resolves current_user to the
      # human, not the service account that owns the token (see
      # Gitlab::Auth::AuthFinders#resolve_composite_identity_user).
      def author
        ::Gitlab::Auth::Identity.resolve_composite_identity_actor(@current_user) || @current_user
      end
      strong_memoize_attr :author

      def reject_event?(event)
        return true if event[:id].blank?
        return true if event[:type].blank?
        return true if event[:time].blank?

        false
      end

      # Tracked manually rather than via the `tracks_event ... on: :success`
      # ServiceTracking DSL: the event must fire only for non-empty batches
      # (the guard below), whereas `on: :success` would fire on every successful
      # `execute`, including empty/all-dropped batches. Emitting a spurious
      # value: 0 event would break the captured/ingested/stored no-loss
      # reconciliation, so the conditional firing is intentional.
      def track_ingest_batch(audit_events)
        return if audit_events.empty?

        store = ::Gitlab::ClickHouse.globally_enabled_for_analytics? ? 'clickhouse' : 'postgresql'

        track_internal_event(
          'ingest_ai_audit_events_batch',
          project: @workflow.project,
          additional_properties: {
            value: audit_events.size,
            property: store
          }
        )
      end
    end
  end
end
