# frozen_string_literal: true

module AuditEvents
  module Streaming
    # Shared classification of streaming dispatch errors, used by both the
    # per-event streamer (BaseStreamer) and the batched dispatcher.
    #
    # Errors originating from user-supplied configuration (invalid
    # credentials, malformed URLs, unreachable endpoints, non-actionable
    # service responses, bad payloads) are not actionable by GitLab, so they
    # are logged rather than paging Sentry, and they trip the per-destination
    # circuit breaker. Everything else is a GitLab-side bug and is reported
    # to Sentry. See commit fde68cd6bd7e.
    module ErrorClassifier
      USER_CONFIG_ERRORS = [
        Aws::Errors::InvalidRegionError,
        Aws::S3::Errors::ServiceError,
        URI::InvalidURIError,
        JSON::ParserError,
        OpenSSL::PKey::RSAError,
        Signet::AuthorizationError,
        *Gitlab::HTTP::HTTP_ERRORS
      ].freeze

      # Maps a destination category to the streamer class whose
      # `log_only_errors` list further classifies category-specific errors.
      STREAMER_DESTINATIONS = {
        'aws' => AuditEvents::Streaming::Destinations::AmazonS3StreamDestination,
        'gcp' => AuditEvents::Streaming::Destinations::GoogleCloudLoggingStreamDestination,
        'http' => AuditEvents::Streaming::Destinations::HttpStreamDestination
      }.freeze

      module_function

      # @param error [StandardError]
      # @param category [String] destination category ('aws'/'gcp'/'http')
      # @return [Boolean] true when the error is caused by user configuration
      #   and should be logged (not reported to Sentry) and count towards the
      #   circuit breaker.
      def log_only?(error, category)
        return true if USER_CONFIG_ERRORS.any? { |klass| error.is_a?(klass) }

        streamer_cls = STREAMER_DESTINATIONS[category]
        return false unless streamer_cls

        streamer_cls.log_only_errors.any? { |klass| error.is_a?(klass) }
      end
    end
  end
end
