# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillSecurityInventoryFilters
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        SEVERITY_COLUMNS = %i[
          info
          unknown
          low
          medium
          high
          critical
          total
        ].freeze

        ANALYZER_TYPES = {
          sast: 0,
          sast_advanced: 1,
          sast_iac: 2,
          dast: 3,
          dependency_scanning: 4,
          container_scanning: 5,
          secret_detection: 6,
          coverage_fuzzing: 7,
          api_fuzzing: 8,
          cluster_image_scanning: 9,
          secret_detection_secret_push_protection: 10,
          container_scanning_for_registry: 11,
          secret_detection_pipeline_based: 12,
          container_scanning_pipeline_based: 13
        }.freeze

        STATUS_VALUES = {
          not_configured: 0,
          success: 1,
          failed: 2
        }.freeze

        ANALYZER_STATUS_DEFAULT = 0 # not_configured

        class Project < ::ApplicationRecord
          self.table_name = 'projects'
        end

        class AnalyzerProjectStatus < ::SecApplicationRecord
          self.table_name = 'analyzer_project_statuses'
        end

        class SecurityInventoryFilter < ::SecApplicationRecord
          self.table_name = 'security_inventory_filters'
        end

        prepended do
          operation_name :backfill_security_inventory_filters
          feature_category :vulnerability_management
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            statistics_records = sub_batch.select(:project_id, :traversal_ids, :archived, *SEVERITY_COLUMNS)
            process_statistics_batch(statistics_records)
          end
        end

        private

        def process_statistics_batch(statistics_records)
          return if statistics_records.empty?

          project_ids = statistics_records.map(&:project_id)
          project_names = fetch_project_names(project_ids)
          analyzer_statuses = fetch_analyzer_statuses(project_ids)

          records_to_upsert = build_upsert_records(
            statistics_records,
            project_names,
            analyzer_statuses
          )

          bulk_upsert(records_to_upsert)
        end

        def fetch_project_names(project_ids)
          Project.where(id: project_ids).pluck(:id, :name).to_h
        end

        def fetch_analyzer_statuses(project_ids)
          AnalyzerProjectStatus
            .where(project_id: project_ids)
            .pluck(:project_id, :analyzer_type, :status)
            .group_by(&:first)
            .transform_values do |records|
              records.to_h { |_, analyzer_type, status| [analyzer_type, status] }
            end
        end

        def build_upsert_records(statistics_records, project_names, analyzer_statuses)
          statistics_records.filter_map do |stat|
            project_name = project_names[stat.project_id]
            next unless project_name

            project_analyzer_statuses = analyzer_statuses[stat.project_id] || {}

            {
              project_id: stat.project_id,
              project_name: project_name,
              traversal_ids: stat.traversal_ids,
              archived: stat.archived,
              **SEVERITY_COLUMNS.index_with { |column| stat[column] || 0 },
              **ANALYZER_TYPES.keys.index_with do |analyzer_type|
                project_analyzer_statuses[ANALYZER_TYPES[analyzer_type]] || ANALYZER_STATUS_DEFAULT
              end
            }
          end
        end

        def bulk_upsert(records)
          return if records.empty?

          SecurityInventoryFilter.upsert_all(records, unique_by: :project_id)
        end
      end
    end
  end
end
