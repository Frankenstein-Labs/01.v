# frozen_string_literal: true

module Analytics
  module AiAnalytics
    module AgentPlatform
      # rubocop: disable CodeReuse/ActiveRecord -- Not ActiveRecord
      class UserFlowCountService
        include CommonUsageService

        FIELDS =
          %i[flow_type sessions_count user].freeze

        private

        def success_payload
          usage_data
        end

        def empty_payload
          []
        end

        def usage_data
          ClickHouse::Client.select(query, :main)
        end

        # Sample query
        #
        # SELECT
        #     user_id,
        #     flow_type,
        #     uniq(session_id) AS sessions_count
        # FROM gitlab_clickhouse_development.agent_platform_sessions
        # WHERE startsWith(namespace_path, '9970/')
        # GROUP BY user_id, flow_type
        # HAVING toDate(anyIfMerge(created_event_at)) >= '2025-11-27'
        #     AND toDate(anyIfMerge(created_event_at)) <= '2025-11-27'
        # ORDER BY count DESC
        def query
          builder = ClickHouse::Client::QueryBuilder.new('agent_platform_sessions')
          table = builder.table

          created_at_date = Arel::Nodes::NamedFunction.new('toDate', [
            Arel::Nodes::NamedFunction.new('anyIfMerge', [table[:created_event_at]])
          ])

          namespace_filter =
            Arel::Nodes::NamedFunction.new('startsWith',
              [Arel.sql('namespace_path'),
                Arel::Nodes.build_quoted(namespace.traversal_path(with_organization: false))])

          builder
            .select(*projections_for(table))
            .where(namespace_filter)
            .group(:flow_type, :user_id)
            .having(created_at_date.gteq(from.to_date.iso8601))
            .having(created_at_date.lteq(to.to_date.iso8601))
            .order(Arel.sql('sessions_count'), :desc)
            .order(:user_id, :asc)
        end

        def projections_for(table)
          sessions_count =
            Arel::Nodes::NamedFunction.new('uniq', [table[:session_id]]).as('sessions_count')

          [:flow_type, :user_id, sessions_count]
        end
      end
      # rubocop: enable CodeReuse/ActiveRecord
    end
  end
end
