# frozen_string_literal: true

module AuditEvents
  module AiAuditEvents
    class ClickHouseFinder
      # rubocop:disable CodeReuse/ActiveRecord -- Not ActiveRecord but a ClickHouse query builder
      TABLE_NAME = 'ai_audit_events'
      COLUMNS = %i[id workflow_id created_at traversal_path event_name author_id ip_address details].freeze

      # `ai_audit_events` uses ReplacingMergeTree with no explicit version column.
      # Deduplication uses GROUP BY on the ORDER BY columns (traversal_path, workflow_id,
      # created_at, id) with `any()` for remaining columns since duplicates are identical.
      GROUP_BY_COLUMNS = %i[traversal_path workflow_id created_at id].freeze

      def self.counts_for_workflows(workflow_ids, min_created_at: nil)
        return {} if workflow_ids.blank?

        # Deduplicate first, then count per workflow_id.
        # Inner query deduplicates by primary key columns.
        inner_builder = ClickHouse::Client::QueryBuilder.new(TABLE_NAME)
          .select(Arel.sql('workflow_id'), Arel.sql('id'))
          .where(workflow_id: workflow_ids)
          .group(*GROUP_BY_COLUMNS)

        if min_created_at.present?
          # Audit events can't predate their workflow, so the earliest
          # `workflow_created_at` in the batch is a safe lower bound. The
          # `ai_audit_events` table is partitioned by `created_at`, so this
          # bound lets ClickHouse prune partitions rather than fanning out.
          inner_builder = inner_builder.where(
            Arel::Table.new(TABLE_NAME)[:created_at].gteq(
              min_created_at.utc.strftime('%Y-%m-%d %H:%M:%S')
            )
          )
        end

        query = ClickHouse::Client::QueryBuilder
          .new(TABLE_NAME)
          .select(Arel.sql('workflow_id'), Arel.sql('count() AS count'))
          .from(inner_builder, TABLE_NAME)
          .group(:workflow_id)

        ::ClickHouse::Client.select(query, :main)
          .each_with_object({}) { |row, hash| hash[row['workflow_id']] = row['count'] }
      end

      def initialize(workflow:)
        @workflow = workflow
      end

      def execute
        inner_builder = ClickHouse::Client::QueryBuilder.new(TABLE_NAME)

        inner_projections = COLUMNS.map do |column|
          if GROUP_BY_COLUMNS.include?(column)
            Arel.sql(column.to_s)
          else
            Arel::Nodes::NamedFunction.new('any', [
              Arel::Table.new(TABLE_NAME)[column]
            ]).as(column.to_s)
          end
        end

        inner_query = inner_builder
          .select(*inner_projections)
          .where(workflow_id: @workflow.id)
          .group(*GROUP_BY_COLUMNS)

        ClickHouse::Client::QueryBuilder
          .new(TABLE_NAME)
          .select(*COLUMNS)
          .from(inner_query, TABLE_NAME)
          .order(:created_at, :desc)
          .order(:id, :desc)
      end
      # rubocop:enable CodeReuse/ActiveRecord
    end
  end
end
