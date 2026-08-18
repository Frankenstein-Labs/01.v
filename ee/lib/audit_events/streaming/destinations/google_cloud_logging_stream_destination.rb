# frozen_string_literal: true

module AuditEvents
  module Streaming
    module Destinations
      class GoogleCloudLoggingStreamDestination < BaseStreamDestination
        # Errors from the GCP path (auth, parsing, GCP API responses) are
        # typically caused by user-supplied configuration and are not actionable
        # by GitLab. Log them rather than paging Sentry. See commit https://gitlab.com/gitlab-org/gitlab/-/commit/fde68cd6bd7ea7a2c3d6a68dbd168ea558161b1
        def self.log_only_errors
          [StandardError]
        end

        def stream
          gcp_logger = AuditEvents::GoogleCloud::LoggingService::Logger.new
          gcp_logger.log(@destination.config["clientEmail"], @destination.secret_token, json_payload)
        end

        # Non-breaking: the Cloud Logging API accepts multiple `entries`, so a
        # batch maps to a multi-entry write.
        def stream_batch(event_bodies)
          gcp_logger = AuditEvents::GoogleCloud::LoggingService::Logger.new
          gcp_logger.log(
            destination.config["clientEmail"],
            destination.secret_token,
            batch_json_payload(event_bodies)
          )
        end

        private

        def json_payload
          { 'entries' => [log_entry] }.to_json
        end

        def batch_json_payload(event_bodies)
          { 'entries' => event_bodies.map { |body| log_entry_for(body) } }.to_json
        end

        def log_entry
          log_entry_for(parse_request_body)
        end

        def log_entry_for(json_payload)
          {
            'logName' => full_log_path,
            'resource' => {
              'type' => 'global'
            },
            'severity' => 'INFO',
            'jsonPayload' => json_payload
          }
        end

        def parse_request_body
          ::Gitlab::Json.safe_parse(request_body)
        rescue JSON::ParserError => e
          Gitlab::ErrorTracking.log_exception(e)
          # For audit events, we prefer to send the data even if it exceeds safe_parse limits
          # rather than lose critical compliance information
          ::Gitlab::Json.parse(request_body)
        end

        def full_log_path
          "projects/#{@destination.config['googleProjectIdName']}/logs/#{@destination.config['logIdName']}"
        end
      end
    end
  end
end
