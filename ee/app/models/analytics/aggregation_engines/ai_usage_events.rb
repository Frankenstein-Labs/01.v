# frozen_string_literal: true

module Analytics
  module AggregationEngines
    class AiUsageEvents < Gitlab::Database::Aggregation::ClickHouse::Engine
      self.table_name = 'ai_usage_events'

      transient(:feature) do
        when_clauses = Gitlab::Tracking::AiTracking.registered_features.map do |feature|
          event_ids = Gitlab::Tracking::AiTracking.registered_events(feature).values
          "WHEN event IN (#{event_ids.join(', ')}) THEN '#{feature}'"
        end

        sql("CASE #{when_clauses.join(' ')} ELSE NULL END")
      end

      dimensions do
        column :feature, :string, transient(:feature), description: 'Feature identifier'
        column :event, :string, description: 'Event identifier',
          formatter: ->(value) { Ai::UsageEvent.events.key(value) }
        column :user_id, :integer, description: 'Event owner', association: true
        date_bucket :timestamp, :datetime, -> {
          sql('timestamp')
        }, description: 'Event timestamp', parameters: {
          granularity: { type: :string, in: %w[daily weekly monthly] }
        }
      end

      metrics do
        count description: 'Total number of events'
        count :users, :integer, -> { sql('user_id') }, distinct: true, description: 'Number of unique users'
        count :features, :integer, transient(:feature), distinct: true, description: 'Number of unique features'
        retained_count :returning_users, :integer, -> { sql('user_id') }, over: :timestamp,
          description: 'Number of users who also used this feature in the previous period'
        lagged_count :previous_period_users, :integer, -> { sql('user_id') }, over: :timestamp,
          description: 'Number of unique users in the previous period'
      end

      filters do
        exact_match :user_id, :string, description: 'Filter by one or many user Global IDs',
          formatter: gid_formatter
        exact_match :event, :string, description: 'Filter by one or many events',
          formatter: ->(values) { Array.wrap(values).filter_map { |v| Ai::UsageEvent.events[v] } }
        exact_match :feature, :string, transient(:feature), description: 'Filter by one or many features'
        range :timestamp, :datetime, description: 'Filter by event timestamp'
        metric_range :features_count, :integer, description: 'Filter by the number of unique features'
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
