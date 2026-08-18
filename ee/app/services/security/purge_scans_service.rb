# frozen_string_literal: true

module Security
  class PurgeScansService
    include Gitlab::Utils::StrongMemoize

    MAX_STALE_SCANS_SIZE = 200_000
    SCAN_BATCH_SIZE = 100

    # To optimise purging against rereading dead tuples on progressive purge executions
    # we cache the last purged tuple so that the next job can start where the prior finished.
    # The TTL for this is in hours so that we'll start from the beginning the following weekend.
    LAST_PURGED_SCAN_TUPLE = 'Security::PurgeScansService::LAST_PURGED_SCAN_TUPLE'
    LAST_PURGED_SCAN_TUPLE_TTL = 24.hours

    class << self
      def purge_stale_records
        execute(Security::Scan.stale.ordered_by_created_at_and_id, redis_cursor.cursor)
      end

      def purge_by_build_ids(build_ids)
        Security::Scan.by_build_ids(build_ids).then { |relation| execute(relation) }
      end

      def execute(security_scans, cursor = {})
        new(security_scans, cursor).execute
      end

      def redis_cursor
        @redis_cursor ||= Gitlab::Redis::CursorStore.new(LAST_PURGED_SCAN_TUPLE, ttl: LAST_PURGED_SCAN_TUPLE_TTL)
      end
    end

    def initialize(security_scans, cursor = {})
      @iterator = Gitlab::Pagination::Keyset::Iterator.new(scope: security_scans, cursor: cursor)
      @updated_count = 0
    end

    def execute
      iterator.each_batch(of: SCAN_BATCH_SIZE) do |batch|
        last_updated_record = batch.last

        @updated_count += purge(batch)

        store_last_purged_tuple(last_updated_record.created_at, last_updated_record.id) if last_updated_record

        break if @updated_count >= MAX_STALE_SCANS_SIZE
      end
    end

    private

    attr_reader :iterator

    def purge(scan_batch)
      scan_batch.update_all(status: :purged)
    end

    # Normal to string methods for dates don't include the split seconds that rails usually includes in queries.
    # Without them, it's possible to still match on the last processed record instead of the one after it.
    def store_last_purged_tuple(created_at, id)
      quoted_time = Security::Scan.connection.quote(created_at)

      self.class.redis_cursor.commit(created_at: quoted_time, id: id)
    end
  end
end
