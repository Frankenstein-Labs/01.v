# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CheckpointBlob < ::ApplicationRecord
      include ::Ai::DuoWorkflows::SyncWorkflowAttributes
      include BulkInsertSafe
      include PartitionedTable

      # Mirrors the octet_length DB check constraint.
      BLOB_DATA_LIMIT = 1_048_576

      # Partitioned by workflow_created_at (= the workflow's created_at, set on
      # every blob), so all of a workflow's blobs share one daily partition and a
      # lookup prunes to it. Daily partitions dropped past retention enforce the TTL.
      partitioned_by :workflow_created_at, strategy: :daily, retain_for: CHECKPOINT_RETENTION_DAYS.days
      self.table_name = :p_duo_workflows_checkpoint_blobs

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true

      validates :workflow, presence: true
      validates :thread_ts, presence: true
      validates :channel, presence: true
      validates :version, presence: true
      validates :write_type, presence: true
      validates :step_action, presence: true, inclusion: { in: %w[conversation compaction] }
      validates :data, presence: true, length: { maximum: BLOB_DATA_LIMIT }

      # The composite [id, created_at] primary key makes a bare id lookup
      # ambiguous, so route single-id finds through find_by_id. Mirrors Checkpoint.
      def self.find(*args)
        if args.length == 1 && !args[0].is_a?(Array)
          find_by_id(args[0])
        else
          super
        end
      end
    end
  end
end
