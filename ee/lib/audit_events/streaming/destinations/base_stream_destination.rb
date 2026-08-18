# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Destinations
      class BaseStreamDestination
        REQUEST_BODY_SIZE_LIMIT = 25.megabytes
        STREAM_ERROR_MESSAGE = 'Subclasses must implement the `stream` method'
        EVENT_TYPE_HEADER_KEY = "X-Gitlab-Audit-Event-Type"

        attr_reader :event_type, :audit_event, :destination

        # Error classes that, when raised by this destination's `stream` method,
        # should be logged via `Gitlab::ErrorTracking.log_exception` instead of
        # being reported to Sentry via `track_exception`. Override in subclasses
        # for destinations whose errors are typically caused by user
        # configuration (invalid credentials, malformed payloads, etc.) and are
        # not actionable by GitLab.
        def self.log_only_errors
          []
        end

        # event_type/audit_event are per-event and do not apply to a batch.
        def self.for_batch(destination)
          new(nil, nil, destination)
        end

        def initialize(event_type, audit_event, destination)
          @event_type = event_type
          @audit_event = audit_event
          @destination = destination
        end

        def stream
          raise NotImplementedError, _(STREAM_ERROR_MESSAGE)
        end

        # @param event_bodies [Array<Hash>] serialized event bodies, each
        #   self-describing (`id`, `event_type`, and event fields).
        def stream_batch(event_bodies)
          raise NotImplementedError, _(STREAM_ERROR_MESSAGE)
        end

        protected

        def encode_body(body)
          Gitlab::Json::LimitedEncoder.encode(body, limit: REQUEST_BODY_SIZE_LIMIT)
        end

        def request_body
          raise ArgumentError, 'request_body requires a per-event instance; use stream_batch for batch-mode' if
            @audit_event.nil?

          body = @audit_event.as_json
          body[:event_type] = @event_type
          # Stream-only events have a blank database id. Prefer the upstream
          # `stream_id` so every destination and transport sees the same ID
          # (customer-side deduplication); fall back to a UUID for events
          # enqueued before `stream_id` existed.
          body["id"] = upstream_stream_id || SecureRandom.uuid if @audit_event.id.blank?
          encode_body(body)
        end

        def upstream_stream_id
          # AuditEvents::AiAuditEvent reaches this layer without
          # CommonAuditEventStreamable (it dedups by `cloud_event_id`), so it
          # has no `stream_id`. Guard removable once all event classes define it.
          return unless @audit_event.respond_to?(:stream_id)

          @audit_event.stream_id.presence
        end
      end
    end
  end
end
