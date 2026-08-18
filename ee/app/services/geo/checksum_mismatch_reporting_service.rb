# frozen_string_literal: true

module Geo
  # Detects registries on a secondary that have persistently failed
  # verification due to a checksum mismatch, and reports them to the primary
  # so it can re-verify (recompute) its own checksum for those resources.
  #
  # See Geo::ChecksumMismatchSelfHealService for the primary-side handler.
  class ChecksumMismatchReportingService < RequestService
    include Gitlab::Geo::LogHelpers

    ERROR_TYPE = 'checksum_mismatch'
    BATCH_SIZE = 100
    # Extra candidates fetched per replicable type so recently-reported ones
    # (skipped via the Redis dedup marker) don't starve the batch.
    CANDIDATE_MULTIPLIER = 3

    def initialize(geo_node)
      @geo_node = geo_node
    end

    def execute
      return false if mismatches.empty?

      response = super(failures_url, payload)

      mark_as_reported!(mismatches) if response

      response
    end

    private

    attr_reader :geo_node

    def failures_url
      primary_node&.checksum_mismatch_reports_url
    end

    def payload
      { geo_node_id: geo_node.id, failures: mismatches }
    end

    def mismatches
      @mismatches ||= Gitlab::Geo.repository_replicator_classes.flat_map do |replicator_class|
        candidates_for(replicator_class)
      end
    end

    # rubocop:disable CodeReuse/ActiveRecord -- chained on the persistent_checksum_mismatches model scope, iterating over registry classes with no single model to place this on
    def candidates_for(replicator_class)
      replicable_name = replicator_class.replicable_name

      registries = replicator_class.registry_class
        .persistent_checksum_mismatches(geo_node.checksum_mismatch_report_threshold)
        .order(:verification_retry_at)
        .limit(BATCH_SIZE * CANDIDATE_MULTIPLIER)
        .to_a

      already_reported = recently_reported_ids(replicable_name, registries.map(&:model_record_id))

      registries
        .reject { |registry| already_reported.include?(registry.model_record_id) }
        .first(BATCH_SIZE)
        .map { |registry| build_entry(replicable_name, registry) }
    end
    # rubocop:enable CodeReuse/ActiveRecord

    def build_entry(replicable_name, registry)
      {
        error_type: ERROR_TYPE,
        replicable_name: replicable_name,
        replicable_id: registry.model_record_id,
        verification_retry_count: registry.verification_retry_count,
        context: { primary_checksum_at_mismatch: registry.verification_checksum_mismatched }
      }
    end

    # Batches the dedup existence checks into a single pipelined round trip
    # per replicable type, instead of one Redis call per candidate.
    def recently_reported_ids(replicable_name, replicable_ids)
      return [] if replicable_ids.empty?

      results = Gitlab::Redis::SharedState.with do |redis|
        redis.pipelined do |pipeline|
          replicable_ids.each { |id| pipeline.exists?(dedup_cache_key(replicable_name, id)) } # rubocop:disable CodeReuse/ActiveRecord -- not ActiveRecord
        end
      end

      replicable_ids.zip(results).filter_map { |id, reported| id if reported }
    end

    def mark_as_reported!(entries)
      ttl = geo_node.checksum_mismatch_self_heal_cooldown_minutes.minutes

      Gitlab::Redis::SharedState.with do |redis|
        redis.pipelined do |pipeline|
          entries.each do |entry|
            pipeline.set(dedup_cache_key(entry[:replicable_name], entry[:replicable_id]), 1, ex: ttl.to_i)
          end
        end
      end
    end

    def dedup_cache_key(replicable_name, replicable_id)
      "geo:checksum_mismatch_reported:#{replicable_name}:#{replicable_id}"
    end
  end
end
