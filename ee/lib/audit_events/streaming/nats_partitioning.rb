# frozen_string_literal: true

module AuditEvents
  module Streaming
    # Shared partitioning scheme for the NATS audit event streaming pipeline.
    #
    # Subjects are partitioned by the top-level group ID into a fixed number
    # of partitions rather than one subject per group. There are millions of
    # top-level groups, far beyond what a single JetStream stream can track as
    # distinct subjects (subject state is held in memory), so a fixed
    # partition count keeps subject cardinality constant regardless of group
    # count.
    #
    # The mapping is deterministic: a given group always maps to the same
    # partition, so all of its events land there in publish order (FIFO per
    # group). The partition count also bounds consumer parallelism: each
    # partition is drained by exactly one worker at a time.
    #
    # Hot partitions: modulo spreads group IDs uniformly, but audit event
    # volume is heavily skewed toward a few large namespaces. Because a
    # partition is drained by a single worker, a high-volume group is
    # head-of-line for every other group sharing its partition. Per-partition
    # throughput skew (not just queue depth) must be measured during shadow
    # mode before PARTITION_COUNT is frozen (see gitlab-org/gitlab#604456).
    #
    # PARTITION_COUNT is set once and generously. Re-partitioning re-hashes
    # group-to-subject assignments and is disruptive after live cutover, so
    # the value is settled during shadow mode and must not be changed lightly
    # afterwards.
    #
    # Cells: subjects are not qualified by cell or environment. If the
    # JetStream cluster is ever shared across cells, group IDs are not unique
    # across cells and subjects would collide. Isolation therefore relies on
    # each cell owning its own stream (or NATS account); see the stream
    # provisioner. Do not share a stream across cells without a qualifier.
    #
    # Invalid input: partition_for raises ArgumentError/TypeError on a
    # malformed group ID (rather than silently mispartitioning). The publish
    # caller runs on an audited request path, so it must treat NATS routing as
    # best-effort: rescue the error, fall back to the Sidekiq streaming path,
    # and never let an instrumentation failure break the audited action.
    module NatsPartitioning
      PARTITION_COUNT = 256
      SUBJECT_PREFIX = 'audit_events.streaming'
      DURABLE_PREFIX = 'audit_streaming_consumer'

      # Instance-scoped (admin) events have no root group. They get a
      # dedicated subject and durable rather than a numeric partition so they
      # are never stuck behind a tenant's backlog: routing them through a
      # shared numeric partition would block them behind roughly
      # 1/PARTITION_COUNT of groups. One extra subject fully isolates them.
      #
      # INSTANCE_KEY is the partition key used by the scheduler and consumer
      # worker for this dedicated lane (alongside the integer partitions).
      INSTANCE_KEY = 'instance'
      INSTANCE_SUBJECT = "#{SUBJECT_PREFIX}.#{INSTANCE_KEY}".freeze
      INSTANCE_DURABLE = "#{DURABLE_PREFIX}_#{INSTANCE_KEY}".freeze

      module_function

      # Every partition key the pipeline drains: one per numeric partition plus
      # the dedicated instance lane. The consumer scheduler fans out over this.
      #
      # @return [Array<Integer, String>]
      def partition_keys
        [*0...PARTITION_COUNT, INSTANCE_KEY]
      end

      # @param group_id [Integer, String, nil] top-level group ID (Integer or
      #   its string form), or nil for instance-scoped events
      # @return [Integer, nil] partition index in [0, PARTITION_COUNT), or nil
      #   for instance-scoped events (which use INSTANCE_KEY / INSTANCE_SUBJECT)
      # @raise [ArgumentError, TypeError] if group_id is present but not a
      #   valid integer
      def partition_for(group_id)
        # Only a true nil means instance-scoped. Use nil? (not blank?) so an
        # empty string or other malformed id falls through to Integer() and
        # fails loudly rather than being silently routed to the instance lane.
        # This also keeps the module free of the ActiveSupport blank? dependency.
        return if group_id.nil?

        # Group IDs come from a Postgres sequence, so `id % PARTITION_COUNT`
        # spreads them evenly across partitions (better than hashing, which
        # would only approximate the uniform distribution sequential IDs give
        # for free). Coerce explicitly: a bare `%` on a String is
        # String#format ("42" % 256 => "42"), which would silently emit a
        # per-group subject and defeat the whole partitioning scheme.
        Integer(group_id) % PARTITION_COUNT
      end

      # @param group_id [Integer, String, nil]
      # @return [String] the subject the group's events publish to, or
      #   INSTANCE_SUBJECT for instance-scoped events
      def subject_for(group_id)
        partition = partition_for(group_id)
        return INSTANCE_SUBJECT if partition.nil?

        subject_for_partition(partition)
      end

      # @param key [Integer, String] a numeric partition index (Integer or its
      #   string form), or INSTANCE_KEY
      # @return [String] the subject for that partition key
      # @raise [ArgumentError] if key is neither a valid partition nor INSTANCE_KEY
      def subject_for_key(key)
        return INSTANCE_SUBJECT if instance_key?(key)

        subject_for_partition(coerce_partition(key))
      end

      # @param key [Integer, String] a numeric partition index (Integer or its
      #   string form), or INSTANCE_KEY
      # @return [String] the durable consumer name for that partition key
      # @raise [ArgumentError] if key is neither a valid partition nor INSTANCE_KEY
      def durable_for_key(key)
        return INSTANCE_DURABLE if instance_key?(key)

        durable_for_partition(coerce_partition(key))
      end

      # @param partition [Integer] partition index in [0, PARTITION_COUNT)
      # @return [String] e.g. "audit_events.streaming.42"
      # @raise [ArgumentError] if partition is out of range
      def subject_for_partition(partition)
        validate_partition!(partition)

        "#{SUBJECT_PREFIX}.#{partition}"
      end

      # @param partition [Integer] partition index in [0, PARTITION_COUNT)
      # @return [String] durable consumer name for a partition
      # @raise [ArgumentError] if partition is out of range
      def durable_for_partition(partition)
        validate_partition!(partition)

        "#{DURABLE_PREFIX}_#{partition}"
      end

      # @param partition [Integer]
      # @raise [ArgumentError] unless partition is in [0, PARTITION_COUNT)
      def validate_partition!(partition)
        return if partition.is_a?(Integer) && (0...PARTITION_COUNT).cover?(partition)

        raise ArgumentError, "partition must be in [0, #{PARTITION_COUNT}), got #{partition.inspect}"
      end

      # A partition key round-trips through Sidekiq args (YAML), Redis, and
      # NATS headers, any of which can stringify it. Match the instance lane by
      # value so both :instance / "instance" and an integer / its string form
      # resolve correctly.
      #
      # @param key [Integer, String]
      # @return [Boolean]
      def instance_key?(key)
        key.to_s == INSTANCE_KEY
      end

      # Coerces a numeric partition key (Integer or its string form) to an
      # Integer, so a stringified key does not blow up validate_partition!.
      # nil and other non-numeric input raise ArgumentError (not TypeError) so
      # subject_for_key / durable_for_key keep a single documented failure mode.
      #
      # @param key [Integer, String]
      # @return [Integer]
      # @raise [ArgumentError] if key is not a valid integer
      def coerce_partition(key)
        Integer(key)
      rescue TypeError
        raise ArgumentError, "partition key must be an integer or its string form, got #{key.inspect}"
      end
    end
  end
end
