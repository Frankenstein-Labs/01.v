# frozen_string_literal: true

module Analytics
  module AggregationEngines
    class AgentPlatformSessions < Gitlab::Database::Aggregation::ClickHouse::Engine
      self.table_name = 'agent_platform_sessions'

      transient(:duration) do
        sql("dateDiff('seconds', anyIfMerge(created_event_at), anyIfMerge(finished_event_at))")
      end
      transient(:is_finished) { sql('anyIfMerge(finished_event_at) IS NOT NULL') }
      transient(:created_event_at) { sql('anyIfMerge(created_event_at)') }

      dimensions do
        column :flow_type, :string, description: 'Type of session'
        column :user_id, :integer, description: 'Session owner', association: true
        date_bucket :created_event_at, :date, transient(:created_event_at),
          description: 'Session creation time', parameters: {
            granularity: { type: :string, in: %w[weekly monthly] }
          }
      end

      metrics do
        count description: 'Total number of sessions'
        count :finished, if: transient(:is_finished), description: 'Number of finished sessions'
        count :users, :integer, -> { sql('user_id') }, distinct: true, description: 'Number of unique users'

        mean :duration, :float, transient(:duration), description: 'Average session duration in seconds'

        rate :completion, numerator_if: transient(:is_finished), description: 'Session completion rate'

        quantile :duration, :float, transient(:duration), description: 'Session duration quantile in seconds',
          parameters: {
            quantile: { type: :float, in: 0.0..1.0 }
          }
      end

      measurement :duration, :integer, transient(:duration), description: 'Session duration in seconds'

      filters do
        exact_match :user_id, :string, description: 'Filter by one or many user Global IDs',
          formatter: gid_formatter
        exact_match :flow_type, :string, description: 'Filter by one or many flow types'
        range :created_event_at, :datetime, transient(:created_event_at),
          merge_column: true,
          description: 'Filter by session creation timestamp'
      end

      def self.prepare_base_aggregation_scope(objects)
        builder = ClickHouse::Client::QueryBuilder.new(table_name)

        conditions = Array.wrap(objects).map do |object|
          namespace = object.is_a?(Project) ? object.project_namespace : object

          builder.func('startsWith', [
            builder[:namespace_path], Arel::Nodes.build_quoted(namespace.traversal_path(with_organization: false).to_s)
          ])
        end

        raise ArgumentError, 'at least one scope object is required' if conditions.empty?

        builder.where(conditions.reduce(:or))
      end
    end
  end
end
