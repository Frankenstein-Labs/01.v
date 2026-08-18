# frozen_string_literal: true

module Analytics
  module AggregationEngines
    class Contributions < Gitlab::Database::Aggregation::ClickHouse::Engine
      self.table_name = 'contributions_new'

      metrics do
        count :users, :integer, -> { sql('author_id') }, distinct: true, description: 'Number of unique contributors'
        count description: 'Total number of contributions'
      end

      filters do
        exact_match :author_id, :string, description: 'Filter by one or many author Global IDs',
          formatter: gid_formatter
        range :created_at, :datetime, description: 'Filter by contribution timestamp'
      end

      dimensions do
        date_bucket :created_at, :datetime, description: 'Contribution timestamp', parameters: {
          granularity: { type: :string, in: %w[daily weekly monthly] }
        }
      end

      def self.prepare_base_aggregation_scope(objects)
        builder = ClickHouse::Client::QueryBuilder.new(table_name)

        conditions = Array.wrap(objects).map do |object|
          namespace = object.is_a?(Project) ? object.project_namespace : object

          builder.func('startsWith', [
            builder[:path],
            Arel::Nodes.build_quoted(namespace.traversal_path(with_organization: true).to_s)
          ])
        end

        raise ArgumentError, 'at least one scope object is required' if conditions.empty?

        builder.where(conditions.reduce(:or))
      end
    end
  end
end
