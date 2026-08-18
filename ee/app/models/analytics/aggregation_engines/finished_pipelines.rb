# frozen_string_literal: true

module Analytics
  module AggregationEngines
    # Deprecated in favor of regular Pipelines engine.
    class FinishedPipelines < Gitlab::Database::Aggregation::ClickHouse::Engine
      self.table_name = 'ci_finished_pipelines'

      dimensions do
        column :status, :string, description: 'Pipeline status'
        column :source, :string, description: 'Pipeline source'
        column :ref, :string, description: 'Pipeline ref'
        column :project_id, :integer, -> {
          sql("toUInt64(splitByChar('/', path)[-2])")
        }, description: 'Project', association: {
          finder: ->(ids) { Project.where(project_namespace_id: ids).index_by(&:project_namespace_id) }
        }
        date_bucket :started_at, :datetime, description: 'Pipeline start time', parameters: {
          granularity: { type: :string, in: %w[daily weekly monthly] }
        }
        date_bucket :finished_at, :datetime, description: 'Pipeline finish time', parameters: {
          granularity: { type: :string, in: %w[daily weekly monthly] }
        }
      end

      metrics do
        count description: 'Total number of pipelines'

        quantile :duration, :float, ->(_params) {
          sql('duration')
        }, description: 'Pipeline duration quantile in seconds', parameters: {
          quantile: { type: :float, in: 0.0..1.0 }
        }

        rate :success, numerator_if: ->(_params) { sql("status = 'success'") }, description: 'Pipeline success rate'
        rate :failure, numerator_if: ->(_params) { sql("status = 'failed'") }, description: 'Pipeline failure rate'
        rate :canceled, numerator_if: ->(_params) { sql("status = 'canceled'") }, description: 'Pipeline canceled rate'
        rate :skipped, numerator_if: ->(_params) { sql("status = 'skipped'") }, description: 'Pipeline skipped rate'
      end

      filters do
        exact_match :status, :string, description: 'Filter by one or many pipeline statuses'
        exact_match :source, :string, description: 'Filter by one or many pipeline sources'
        exact_match :ref, :string, description: 'Filter by one or many pipeline refs'
        range :started_at, :datetime, description: 'Filter by pipeline start timestamp'
        range :finished_at, :datetime, description: 'Filter by pipeline finish timestamp'
        metric_exact_match :success_rate, :float, description: 'Filter by exact pipeline success rate'
      end

      def self.prepare_base_aggregation_scope(objects)
        builder = ClickHouse::Client::QueryBuilder.new(table_name)

        conditions = Array.wrap(objects).map do |object|
          namespace = object.is_a?(Project) ? object.project_namespace : object

          builder.func('startsWith', [
            builder[:path],
            Arel::Nodes.build_quoted(namespace.traversal_path(with_organization: false).to_s)
          ])
        end

        raise ArgumentError, 'at least one scope object is required' if conditions.empty?

        builder.where(conditions.reduce(:or))
      end
    end
  end
end
