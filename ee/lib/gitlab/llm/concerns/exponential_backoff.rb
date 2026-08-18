# frozen_string_literal: true

module Gitlab
  module Llm
    module Concerns
      module ExponentialBackoff
        extend ActiveSupport::Concern

        INITIAL_DELAY = 1.second
        EXPONENTIAL_BASE = 2
        MAX_RETRIES = 3

        RateLimitError = Class.new(StandardError)

        def self.included(base)
          base.extend(ExponentialBackoff)
        end

        def retry_with_exponential_backoff(&block)
          Gitlab::CircuitBreaker.run_with_circuit(service_name) do
            retry_with_monitored_exponential_backoff(&block)
          end
        end

        private

        def retry_with_monitored_exponential_backoff(&block)
          response = run_retry_with_exponential_backoff(&block)
        ensure
          success = (200...299).cover?(response&.code)
          client = Gitlab::Metrics::Llm.client_label(self.class)

          Gitlab::Metrics::Sli::ErrorRate[:llm_client_request].increment(labels: { client: client }, error: !success)
        end

        def run_retry_with_exponential_backoff
          retries = 0
          delay = INITIAL_DELAY

          loop do
            response = yield

            return unless response.present?

            return if response.response.nil?

            raise Gitlab::CircuitBreaker::InternalServerError if response.server_error?

            return response unless response.too_many_requests? || retry_immediately?(response)

            retries += 1
            raise RateLimitError, "Maximum number of retries (#{MAX_RETRIES}) exceeded." if retries >= MAX_RETRIES

            delay *= EXPONENTIAL_BASE * (1 + Random.rand)
            log_info(message: "Too many requests, will retry in #{delay} seconds",
              event_name: 'retrying_request',
              ai_component: 'abstraction_layer')

            sleep delay
            next
          end
        end

        # Override in clients to create custom retry conditions, such as the content moderation retry
        # in the VertexAi::Client.
        def retry_immediately?(_response)
          false
        end

        def service_name
          self.class.name
        end
      end
    end
  end
end
