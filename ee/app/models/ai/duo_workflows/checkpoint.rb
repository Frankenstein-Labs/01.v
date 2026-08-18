# frozen_string_literal: true

module Ai
  module DuoWorkflows
    CHECKPOINT_RETENTION_DAYS = 30

    # `p_duo_workflows_checkpoints` is deprecated. Do not add new features to this model.
    # `checkpoint_headers` and `checkpoint_blobs` are the target tables going forward.
    # See https://gitlab.com/groups/gitlab-org/-/work_items/22628.
    class Checkpoint < ::ApplicationRecord
      include ::Ai::DuoWorkflows::SyncWorkflowAttributes
      include PartitionedTable

      attr_accessor :compressed_checkpoint

      partitioned_by :created_at, strategy: :daily, retain_for: CHECKPOINT_RETENTION_DAYS.days
      self.table_name = :p_duo_workflows_checkpoints

      belongs_to :workflow, class_name: 'Ai::DuoWorkflows::Workflow'
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true

      # checkpoint_writes and checkpoint_blobs can be created independently on checkpoints by langgraph so they are
      # associated only by langgraph's thread_ts
      has_many :checkpoint_writes, ->(checkpoint) { where(workflow_id: checkpoint.workflow_id) },
        foreign_key: :thread_ts, primary_key: :thread_ts, inverse_of: :checkpoint
      has_many :checkpoint_blobs, ->(checkpoint) { where(workflow_id: checkpoint.workflow_id) },
        foreign_key: :thread_ts, primary_key: :thread_ts, inverse_of: false

      validates :thread_ts, presence: true
      validates :checkpoint, presence: true
      validates :metadata, presence: true

      # Normalizes a blank checkpoint_ns (e.g. '' sent by a caller for the
      # top-level lineage) to nil on write, so it always matches the `nil`
      # `for_checkpoint_ns`/`earliest`/`latest` normalize blank arguments to
      # when querying. Without this, a row persisted with checkpoint_ns: ''
      # would not match `checkpoint_ns IS NULL` and become unreachable via
      # those scopes.
      before_validation :normalize_checkpoint_ns

      after_save :touch_workflow

      scope :ordered_with_writes, -> { includes(:checkpoint_writes).order(thread_ts: :desc) }
      scope :with_checkpoint_writes, -> { includes(:checkpoint_writes) }
      # Order by created_at DESC, id DESC for offset pagination.
      # id is the tie-breaker because created_at has second-level granularity.
      scope :order_by_created_at_desc, -> { order(created_at: :desc, id: :desc) }

      CLOCK_SKEW_BUFFER = 1.hour

      # `p_duo_workflows_checkpoints` is partitioned by RANGE (created_at).
      # Bounding created_at lets Postgres prune partitions instead of scanning
      # every one (including the empty future-dated partitions).
      scope :created_on_or_before, ->(time) { where(created_at: ..time) }
      # See the comment on `.earliest`/`.latest` for what `checkpoint_ns` represents.
      scope :for_checkpoint_ns, ->(checkpoint_ns) { where(checkpoint_ns: checkpoint_ns.presence) }

      # Single ID lookups are possible due to database trigger
      # [id, created_at] being composite id due to partitioning
      def self.find(*args)
        if args.length == 1 && !args[0].is_a?(Array)
          find_by_id(args[0])
        else
          super
        end
      end

      # `checkpoint_ns` identifies which LangGraph checkpoint lineage a row
      # belongs to: the top-level flow graph itself (checkpoint_ns nil/blank,
      # matching all pre-existing rows, which predate this column) or one
      # specific nested subgraph invocation, e.g. a delegated subagent
      # dispatched by `DelegationNode` (a non-blank LangGraph-assigned
      # namespace string, e.g. "delegation:<task_id>"). Blank is normalized to
      # `nil` so a caller asking for the top-level lineage (the common case)
      # matches every existing row regardless of whether it stored `nil` or
      # `''`.
      def self.earliest(checkpoint_ns: nil)
        created_on_or_before(Time.current + CLOCK_SKEW_BUFFER)
          .for_checkpoint_ns(checkpoint_ns)
          .order(thread_ts: :asc).first
      end

      def self.latest(checkpoint_ns: nil)
        created_on_or_before(Time.current + CLOCK_SKEW_BUFFER)
          .for_checkpoint_ns(checkpoint_ns)
          .order(thread_ts: :desc).first
      end

      def to_global_id(_options = {})
        GlobalID.new(::Gitlab::GlobalId.build(self, id: id.first))
      end
      alias_method :to_gid, :to_global_id

      def ui_chat_log
        log = checkpoint&.dig('channel_values', 'ui_chat_log')
        log.is_a?(Array) ? log : []
      end

      private

      def normalize_checkpoint_ns
        self.checkpoint_ns = checkpoint_ns.presence
      end

      def touch_workflow
        workflow.touch
      end
    end
  end
end
