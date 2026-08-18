# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CheckpointHeader < ::ApplicationRecord
      include ::Ai::DuoWorkflows::SyncWorkflowAttributes
      include BulkInsertSafe
      include PartitionedTable

      # Partitioned by workflow_created_at (= the workflow's created_at, set on
      # every row), so all of a workflow's headers share one daily partition and a
      # lookup prunes to it. Daily partitions dropped past retention enforce the TTL.
      partitioned_by :workflow_created_at, strategy: :daily, retain_for: CHECKPOINT_RETENTION_DAYS.days
      self.table_name = :p_duo_workflows_checkpoint_headers

      # Set on read to serve the reconstructed checkpoint compressed; mirrors Checkpoint.
      attr_accessor :compressed_checkpoint

      # Set on read to batch-load writes for several headers in one query, bypassing
      # the per-instance query in #checkpoint_writes. See
      # API::Ai::DuoWorkflows::WorkflowsInternal's checkpoint list endpoint.
      attr_writer :checkpoint_writes_preload

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true

      validates :workflow, presence: true
      validates :thread_ts, presence: true

      # DWS checkpoint order, oldest first: by thread_ts (the time-ordered UUID
      # that is the authoritative sequence), then id to break ties between
      # re-sends of one thread_ts (latest wins). Not created_at or a bare id,
      # which follow Rails insert arrival and can reorder under retries or skew.
      scope :in_checkpoint_order, -> { order(:thread_ts, :id) }
      # Newest first, for the checkpoint list endpoint. Mirrors the ordering of
      # `Checkpoint.ordered_with_writes`, which it replaces there.
      scope :in_reverse_checkpoint_order, -> { order(thread_ts: :desc, id: :desc) }

      # Headers in one current_thread (compaction) group, oldest first, so the
      # last row is the newest checkpoint.
      scope :for_current_thread, ->(current_thread) { where(current_thread: current_thread).in_checkpoint_order }
      # No presence validation on checkpoint/metadata: they are jsonb NOT NULL at the
      # DB level, and the slim header (checkpoint minus channel_values) can legitimately
      # be an empty hash for a minimal checkpoint. A presence failure here would roll
      # back the whole checkpoint transaction (the header is a shadow write).

      # See `Checkpoint#checkpoint_ns` for what the namespace represents. Blank is
      # normalized to nil so a caller asking for the top-level lineage matches rows
      # written before the column existed. Mirrors `Checkpoint.for_checkpoint_ns`.
      scope :for_checkpoint_ns, ->(checkpoint_ns) { where(checkpoint_ns: checkpoint_ns.presence) }

      # A row persisted with '' would not match `for_checkpoint_ns(nil)` and become
      # unreachable through it. Mirrors Checkpoint's callback of the same name.
      before_validation :normalize_checkpoint_ns

      # The composite [id, workflow_created_at] primary key makes a bare id lookup
      # ambiguous, so route single-id finds through find_by_id. Mirrors CheckpointBlob.
      def self.find(*args)
        if args.length == 1 && !args[0].is_a?(Array)
          find_by_id(args[0])
        else
          super
        end
      end

      # checkpoint_writes are created independently by langgraph, associated only by
      # thread_ts scoped to the workflow. A plain query rather than has_many because
      # BulkInsertSafe forbids the autosave callback a collection association adds.
      def checkpoint_writes
        @checkpoint_writes_preload ||
          ::Ai::DuoWorkflows::CheckpointWrite.where(workflow_id: workflow_id, thread_ts: thread_ts)
      end

      private

      def normalize_checkpoint_ns
        self.checkpoint_ns = checkpoint_ns.presence
      end
    end
  end
end
