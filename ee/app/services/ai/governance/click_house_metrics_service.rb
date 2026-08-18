# frozen_string_literal: true

module Ai
  module Governance
    class ClickHouseMetricsService
      # Mirrors Ai::DuoWorkflows::Workflow::AGENT_INSTANCE_KEY. Internal DAP sessions key
      # on (user, container, normalized environment), where the container is both
      # project_id and namespace_id, external ones on
      # (user, project, agent_type, agent_identity_id), discriminated by agent_type
      # being NULL. agent_identity_id is siphoned, so both paths agree.
      #
      # The environment mapping is derived from the same model constants the PostgreSQL
      # key uses, so the two cannot drift. `transform` passes NULL through unchanged.
      NORMALIZED_ENVIRONMENT =
        begin
          environments = ::Ai::DuoWorkflows::Workflow.environments
          renamed_from, renamed_to = ::Ai::DuoWorkflows::Workflow::ENVIRONMENTS_DEPRECATIONS
            .map { |from, to| [environments.fetch(from), environments.fetch(to)] }
            .transpose

          "transform(environment, [#{renamed_from.join(', ')}], [#{renamed_to.join(', ')}], environment)".freeze
        end

      AGENT_INSTANCE_KEY =
        "(#{::Ai::DuoWorkflows::Workflow::AGENT_INSTANCE_KEY_COLUMNS.join(', ')}, " \
          "if(agent_type IS NULL, #{NORMALIZED_ENVIRONMENT}, NULL))".freeze

      TOTALS_QUERY = <<~SQL.freeze
        SELECT
          countIf(created_at >= {from:DateTime64(6, 'UTC')}) AS sessions_count,
          countIf(created_at < {from:DateTime64(6, 'UTC')}) AS sessions_previous_count,
          uniqExactIf(#{AGENT_INSTANCE_KEY}, created_at >= {from:DateTime64(6, 'UTC')}) AS agents_count,
          uniqExactIf(#{AGENT_INSTANCE_KEY}, created_at < {from:DateTime64(6, 'UTC')}) AS agents_previous_count
        FROM (%{dedup_subquery})
        WHERE deleted = false
          AND workflow_definition NOT IN {excluded_definitions:Array(String)}
          %{agent_class_filter}
      SQL

      TREND_QUERY = <<~SQL.freeze
        SELECT
          toStartOfInterval(created_at, INTERVAL 1 %{unit}) AS bucket_start,
          count() AS sessions_count,
          uniqExact(#{AGENT_INSTANCE_KEY}) AS agents_count
        FROM (%{dedup_subquery})
        WHERE deleted = false
          AND created_at >= {from:DateTime64(6, 'UTC')}
          AND workflow_definition NOT IN {excluded_definitions:Array(String)}
          %{agent_class_filter}
        GROUP BY bucket_start
        ORDER BY bucket_start ASC
      SQL

      DEDUP_SUBQUERY = <<~SQL
        SELECT
          id,
          created_at,
          argMax(workflow_definition, _siphon_replicated_at) AS workflow_definition,
          argMax(user_id, _siphon_replicated_at) AS user_id,
          argMax(project_id, _siphon_replicated_at) AS project_id,
          argMax(namespace_id, _siphon_replicated_at) AS namespace_id,
          argMax(environment, _siphon_replicated_at) AS environment,
          argMax(agent_type, _siphon_replicated_at) AS agent_type,
          argMax(agent_identity_id, _siphon_replicated_at) AS agent_identity_id,
          argMax(_siphon_deleted, _siphon_replicated_at) AS deleted
        FROM siphon_duo_workflows_workflows
        WHERE startsWith(traversal_path, {traversal_path:String})
          AND created_at >= {previous_from:DateTime64(6, 'UTC')}
          AND created_at < {to:DateTime64(6, 'UTC')}
        GROUP BY traversal_path, created_at, id
      SQL

      # agent_class => SQL fragment on the deduplicated `agent_type` column.
      # Values come from a GraphQL enum, so these are fixed, non-interpolated
      # fragments (no injection surface).
      AGENT_CLASS_FILTERS = {
        internal_dap: 'AND agent_type IS NULL',
        external: 'AND agent_type IS NOT NULL'
      }.freeze

      def initialize(container, current_user:, timeframe:, agent_class: :all)
        @container = container
        @current_user = current_user
        @timeframe = timeframe
        @agent_class = agent_class
      end

      def execute
        totals = select(format(TOTALS_QUERY, dedup_subquery: DEDUP_SUBQUERY,
          agent_class_filter: agent_class_filter)).first || {}
        trend_rows = select(format(TREND_QUERY, dedup_subquery: DEDUP_SUBQUERY,
          unit: interval_unit, agent_class_filter: agent_class_filter))

        ServiceResponse.success(payload: {
          sessions: kpi(totals, trend_rows, 'sessions_count'),
          agents: kpi(totals, trend_rows, 'agents_count')
        })
      end

      private

      attr_reader :container, :current_user, :timeframe, :agent_class

      def agent_class_filter
        AGENT_CLASS_FILTERS.fetch(agent_class, '')
      end

      def kpi(totals, trend_rows, count_key)
        counts = trend_rows.to_h { |row| [parse_bucket(row['bucket_start']), row[count_key].to_i] }

        {
          count: totals[count_key].to_i,
          previous_count: totals["#{count_key.delete_suffix('_count')}_previous_count"].to_i,
          trend: timeframe.bucket_starts.map do |bucket_start|
            { bucket_start: bucket_start, count: counts.fetch(bucket_start, 0) }
          end
        }
      end

      def select(raw_query)
        query = ClickHouse::Client::Query.new(raw_query: raw_query, placeholders: placeholders)
        ClickHouse::Client.select(query, :main)
      end

      def placeholders
        @placeholders ||= {
          traversal_path: traversal_path,
          excluded_definitions: MetricsService::EXCLUDED_DEFINITIONS,
          from: format_time(timeframe.from),
          previous_from: format_time(timeframe.previous_from),
          to: format_time(timeframe.to)
        }
      end

      def traversal_path
        namespace = container.is_a?(Project) ? container.project_namespace : container
        namespace.traversal_path(with_organization: true)
      end

      def interval_unit
        timeframe.hourly? ? 'hour' : 'day'
      end

      def format_time(time)
        time.utc.strftime('%Y-%m-%d %H:%M:%S.%6N')
      end

      def parse_bucket(value)
        value.is_a?(String) ? Time.parse("#{value} UTC").utc : value.to_time.utc
      end
    end
  end
end
