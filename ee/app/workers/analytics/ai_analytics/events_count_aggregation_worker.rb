# frozen_string_literal: true

module Analytics
  module AiAnalytics
    class EventsCountAggregationWorker
      include ApplicationWorker
      include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- This worker does not perform work scoped to a context

      idempotent!
      deduplicate :until_executed
      data_consistency :sticky
      feature_category :value_stream_management

      CURSOR_KEY = 'ai_events_counts_cursor'

      def perform
        cursor = load_cursor

        return unless cursor

        runtime_limiter = Gitlab::Metrics::RuntimeLimiter.new

        service_response =
          ::Analytics::AiAnalytics::UsageEventsCounterService.new(
            cursor: cursor.to_i,
            runtime_limiter: runtime_limiter
          ).execute

        raise service_response[:exception] if service_response[:exception].present?

      ensure
        persist_cursor(service_response[:last_processed_id]) if service_response
      end

      private

      def load_cursor
        value = Gitlab::Redis::SharedState.with { |redis| redis.get(CURSOR_KEY) }

        value || ::Ai::UsageEvent.minimum(:id)
      end

      def persist_cursor(last_processed_id)
        Gitlab::Redis::SharedState.with { |redis| redis.set(CURSOR_KEY, last_processed_id) }
      end
    end
  end
end
