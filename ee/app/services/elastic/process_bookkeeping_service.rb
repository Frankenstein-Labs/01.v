# frozen_string_literal: true

module Elastic
  class ProcessBookkeepingService
    SHARDS_MIN = 1
    SHARDS_MAX = 16
    SHARD_LIMIT = 1_000
    SHARDS = 0.upto(SHARDS_MAX - 1).to_a

    class << self
      def active_number_of_shards
        Gitlab::CurrentSettings.elasticsearch_worker_number_of_shards.clamp(self::SHARDS_MIN, self::SHARDS_MAX)
      end

      def shard_number(data)
        Elastic::BookkeepingShardService.shard_number(number_of_shards: active_number_of_shards, data: data)
      end

      def redis_set_key(shard_number)
        "elastic:incremental:updates:#{shard_number}:zset"
      end

      def redis_score_key(shard_number)
        "elastic:incremental:updates:#{shard_number}:score"
      end

      # Add some records to the processing queue. Items must be serializable to a Search::Elastic::Reference
      def track!(*items)
        return true if items.empty?

        # flatten! is temporary to support Vulnerabilities::Read - elastic_reference returning an array
        # during dual write. Remove when dual write is removed.
        items.map! { |item| ::Search::Elastic::Reference.serialize(item) }.flatten!

        items_by_shard = items.group_by { |item| shard_number(item) }

        with_redis do |redis|
          items_by_shard.each do |shard_number, shard_items|
            set_key = redis_set_key(shard_number)

            # Efficiently generate a guaranteed-unique score for each item
            max = redis.incrby(redis_score_key(shard_number), shard_items.size)
            min = (max - shard_items.size) + 1

            (min..max).zip(shard_items).each_slice(1000) do |group|
              logger.debug(
                'class' => name,
                'message' => 'track_items',
                'meta.indexing.redis_set' => set_key,
                'meta.indexing.count' => group.count,
                'meta.indexing.tracked_items_encoded' => group.to_json
              )

              redis.zadd(set_key, group)
            end
          end
        end

        true
      end

      def queue_size
        with_redis do |redis|
          SHARDS.sum do |shard_number|
            redis.zcard(redis_set_key(shard_number))
          end
        end
      end

      def queued_items
        {}.tap do |hash|
          with_redis do |redis|
            each_queued_items_by_shard(redis) do |shard_number, specs|
              hash[shard_number] = specs if specs.present?
            end
          end
        end
      end

      def clear_tracking!
        with_redis do |redis|
          Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
            keys = SHARDS.flat_map { |m| [redis_set_key(m), redis_score_key(m)] }

            if Gitlab::Redis::ClusterUtil.cluster?(redis)
              Gitlab::Redis::ClusterUtil.batch_unlink(keys, redis)
            else
              redis.unlink(*keys)
            end
          end
        end
      end

      def each_queued_items_by_shard(redis, shards: SHARDS)
        (shards & SHARDS).each do |shard_number|
          set_key = redis_set_key(shard_number)
          specs = redis.zrangebyscore(set_key, '-inf', '+inf', limit: [0, shard_limit], with_scores: true)

          yield shard_number, specs
        end
      end

      def logger
        # build already caches the logger via request store
        ::Gitlab::Elasticsearch::Logger.build
      end

      def with_redis(&blk)
        Gitlab::Redis::SharedState.with(&blk) # rubocop:disable CodeReuse/ActiveRecord
      end

      def maintain_indexed_associations(object, associations)
        each_indexed_association(object, associations) do |_, association|
          association.find_in_batches do |group|
            track!(*group)
          end
        end
      end

      def maintain_indexed_namespace_associations!(*namespaces, associations_to_index: [:epics, :work_items])
        namespaces.each do |namespace|
          next unless namespace.use_elasticsearch?

          # Epics are only for group level namespaces
          filtered_associations = namespace.group_namespace? ? associations_to_index : associations_to_index - [:epics]
          ElasticAssociationIndexerWorker.perform_async(namespace.class.name, namespace.id,
            filtered_associations.map(&:to_s))
        end
      end

      private

      def each_indexed_association(object, associations)
        associations.each do |association_name|
          association = object.association(association_name)
          scope = association.scope
          klass = association.klass
          scope = scope.searchable if [Note, Issue].include? klass

          yield klass, scope
        end
      end

      def shard_limit
        SHARD_LIMIT
      end
    end

    def execute(shards: SHARDS)
      self.class.with_redis { |redis| execute_with_redis(redis, shards: shards) }
    end

    private

    def current_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def execute_with_redis(redis, shards:) # rubocop:disable Metrics/AbcSize
      start_time = current_time

      specs_buffer = []
      scores = {}

      self.class.each_queued_items_by_shard(redis, shards: shards) do |shard_number, specs|
        next if specs.empty?

        set_key = self.class.redis_set_key(shard_number)
        first_score = specs.first.last
        last_score = specs.last.last

        logger.info(
          'class' => self.class.name,
          'message' => 'bulk_indexing_start',
          'meta.indexing.redis_set' => set_key,
          'meta.indexing.records_count' => specs.count,
          'meta.indexing.first_score' => first_score,
          'meta.indexing.last_score' => last_score
        )

        specs_buffer += specs

        scores[set_key] = [first_score, last_score, specs.count]
      end

      return [0, 0] if specs_buffer.blank?

      indexing_durations = []
      refs = deserialize_all(specs_buffer)
      total_bytes = 0

      Search::Elastic::Reference.preload_database_records(refs).each do |ref|
        total_bytes += submit_document(ref)

        indexing_duration = ref.database_record&.try(:updated_at)&.then { |updated| Time.current - updated } || 0.0
        indexing_durations << indexing_duration
      end

      flushing_duration_s = Benchmark.realtime do
        @failures = bulk_indexer.flush
      end

      indexed_bytes_per_second = (total_bytes / (current_time - start_time)).ceil

      logger.info(
        'class' => self.class.name,
        'message' => 'bulk_indexer_flushed',
        'meta.indexing.search_flushing_duration_s' => flushing_duration_s,
        'meta.indexing.search_indexed_bytes_per_second' => indexed_bytes_per_second
      )
      Gitlab::Metrics::GlobalSearchIndexingSlis.record_bytes_per_second_apdex(
        throughput: indexed_bytes_per_second,
        target: indexing_bytes_per_second_target
      )

      # Route failures to retry queue or dead queue
      track_failures!(@failures)

      # Remove all the successes
      scores.each do |set_key, (first_score, last_score, count)|
        redis.zremrangebyscore(set_key, first_score, last_score)

        logger.info(
          'class' => self.class.name,
          'message' => 'bulk_indexing_end',
          'meta.indexing.redis_set' => set_key,
          'meta.indexing.records_count' => count,
          'meta.indexing.first_score' => first_score,
          'meta.indexing.last_score' => last_score,
          'meta.indexing.failures_count' => @failures.count,
          'meta.indexing.bulk_execution_duration_s' => current_time - start_time
        )
      end

      refs.each_with_index do |ref, index|
        next if @failures.include?(ref)

        klass = ref.klass.to_s

        logger.info(
          'class' => self.class.name,
          'message' => 'indexing_done',
          'meta.indexing.reference_class' => klass,
          'meta.indexing.database_id' => ref.database_id,
          'meta.indexing.identifier' => ref.identifier,
          'meta.indexing.routing' => ref.routing,
          'meta.indexing.search_indexing_duration_s' => indexing_durations[index],
          'meta.indexing.search_indexing_flushing_duration_s' => flushing_duration_s
        )
      end

      [specs_buffer.count, @failures.count]
    end

    def deserialize_all(specs)
      refs = []
      specs.each do |spec, _|
        refs << Search::Elastic::Reference.deserialize(spec)
      rescue Search::Elastic::Reference::InvalidError, Search::Elastic::DocumentReference::InvalidError => err
        logger.error(
          'class' => self.class.name,
          'message' => 'submit_document_failed',
          'error_class' => err.class.to_s,
          'error_message' => err.message,
          'meta.indexing.reference' => spec
        )
      end

      refs.compact
    end

    def submit_document(ref)
      bulk_indexer.process(ref)
    end

    def bulk_indexer
      @bulk_indexer ||= ::Search::Elastic::BulkIndexer.new(logger: logger)
    end

    def logger
      self.class.logger
    end

    def indexing_bytes_per_second_target
      Gitlab::Metrics::GlobalSearchIndexingSlis::INCREMENTAL_INDEXED_BYTES_PER_SECOND_TARGET
    end

    def track_failures!(failures)
      return if failures.empty?

      target_queue =
        if instance_of?(Search::Elastic::RetryQueue)
          Search::Elastic::DeadQueue
        else
          Search::Elastic::RetryQueue
        end

      target_queue.track!(*failures)
    end
  end
end
