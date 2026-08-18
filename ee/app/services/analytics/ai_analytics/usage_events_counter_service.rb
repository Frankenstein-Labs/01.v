# frozen_string_literal: true

module Analytics
  module AiAnalytics
    # rubocop: disable CodeReuse/ActiveRecord -- a batch data loader is intended to work with AR directly
    class UsageEventsCounterService
      MAX_ROWS_PROCESSED = 5000
      GROUPING_BATCH_SIZE = 200

      GROUPING_COLUMNS = [
        :organization_id,
        :events_date,
        :namespace_id,
        :user_id,
        :event
      ].freeze

      SELECT_COLUMNS = [
        :organization_id,
        Arel.sql("date_trunc('day', timestamp)::date AS events_date"),
        :namespace_id,
        :user_id,
        :event,
        Arel.sql("count(*) AS total_occurrences")
      ].freeze

      UNIQUE_TUPLE = [
        :events_date,
        :namespace_id,
        :event,
        :user_id
      ].freeze

      def initialize(cursor:, runtime_limiter:)
        # Allows using 'greater than' operator when fetching records,
        # also prevents the latest record to be reprocessed if new rows
        # are not present.
        @cursor = cursor - 1

        @runtime_limiter = runtime_limiter
      end

      def execute
        last_processed_id = cursor
        total_processed_rows = 0
        status = :finished

        ::Ai::UsageEvent.where('id > ?', cursor).each_batch(of: GROUPING_BATCH_SIZE) do |batch|
          break if total_processed_rows >= MAX_ROWS_PROCESSED

          if runtime_limiter.over_time?
            status = :interrupted

            break
          end

          last_processed_id, rows_processed = process_batch(batch)
          total_processed_rows += rows_processed
        end

        response(result: status, cursor: last_processed_id)
      rescue StandardError => e
        Gitlab::ErrorTracking.log_exception(e, last_processed_id: last_processed_id,
          processed_rows: total_processed_rows)
        response(result: :error, cursor: last_processed_id, exception: e)
      end

      private

      attr_reader :cursor, :total_processed_rows, :runtime_limiter

      def process_batch(batch)
        records = batch
          .group(*GROUPING_COLUMNS)
          .select(*SELECT_COLUMNS)
          .map { |record| record.attributes.except('id') }

        ::Ai::EventsCount.upsert_all(
          records,
          unique_by: UNIQUE_TUPLE,
          on_duplicate: Arel.sql(
            "total_occurrences = ai_events_counts.total_occurrences + EXCLUDED.total_occurrences"
          )
        )

        [batch.last.id, batch.size]
      end

      def response(result:, cursor:, exception: nil)
        payload =
          { last_processed_id: cursor, result: result, exception: exception }

        if result == :error
          ServiceResponse.error(payload: payload, message: 'Failed to process ai usage events')
        else
          ServiceResponse.success(payload: payload)
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord
  end
end
