# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillAnalyzerProjectStatusesFromProjectSecuritySettings
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        ANALYZER_TYPES = {
          container_scanning: 5,
          secret_detection: 6,
          secret_detection_secret_push_protection: 10,
          container_scanning_for_registry: 11,
          secret_detection_pipeline_based: 12,
          container_scanning_pipeline_based: 13
        }.freeze

        TYPE_MAPPINGS = {
          secret_detection: {
            pipeline_type: :secret_detection_pipeline_based,
            setting_type: :secret_detection_secret_push_protection
          },
          container_scanning: {
            pipeline_type: :container_scanning_pipeline_based,
            setting_type: :container_scanning_for_registry
          }
        }.freeze

        STATUS_FAILED = 2
        STATUS_SUCCESS = 1
        STATUS_NOT_CONFIGURED = 0

        class AnalyzerProjectStatus < ::SecApplicationRecord
          self.table_name = 'analyzer_project_statuses'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            security_settings = fetch_security_settings(sub_batch)
            analyzer_statuses = build_setting_based_analyzer_statuses(security_settings)
            next if analyzer_statuses.empty?

            analyzer_statuses_to_insert = add_aggregated_type_statuses(analyzer_statuses)
            upsert_analyzer_statuses(analyzer_statuses_to_insert)
          end
        end

        private

        def fetch_security_settings(sub_batch)
          sub_batch
            .where('container_scanning_for_registry_enabled = true OR secret_push_protection_enabled = true')
            .joins('INNER JOIN projects ON projects.id = project_security_settings.project_id')
            .joins('INNER JOIN namespaces ON projects.namespace_id = namespaces.id')
            .pluck(:project_id,
              :container_scanning_for_registry_enabled,
              :secret_push_protection_enabled,
              :traversal_ids)
        end

        def build_setting_based_analyzer_statuses(security_settings)
          analyzer_statuses = []

          security_settings.each do |project_id, container_scanning_enabled, secret_protection_enabled, traversal_ids|
            if secret_protection_enabled
              analyzer_statuses << build_status_record(project_id, traversal_ids,
                ANALYZER_TYPES[:secret_detection_secret_push_protection])
            end

            if container_scanning_enabled
              analyzer_statuses << build_status_record(project_id, traversal_ids,
                ANALYZER_TYPES[:container_scanning_for_registry])
            end
          end

          analyzer_statuses
        end

        def build_status_record(project_id, traversal_ids, analyzer_type, status = STATUS_SUCCESS)
          {
            'project_id' => project_id,
            'traversal_ids' => traversal_ids,
            'status' => status,
            'analyzer_type' => analyzer_type,
            'last_call' => Time.current,
            'created_at' => Time.current,
            'updated_at' => Time.current
          }
        end

        def fetch_existing_analyzer_statuses(project_ids)
          AnalyzerProjectStatus.where(project_id: project_ids)
            .where(analyzer_type: [ANALYZER_TYPES[:secret_detection_pipeline_based],
              ANALYZER_TYPES[:container_scanning_pipeline_based]])
            .select(:project_id, :analyzer_type, :last_call, :status)
            .index_by { |status| [status.project_id, status.analyzer_type] }
        end

        def add_aggregated_type_statuses(setting_based_statuses)
          project_ids = setting_based_statuses.pluck('project_id').uniq
          return setting_based_statuses if project_ids.empty?

          existing_pipeline_statuses = fetch_existing_analyzer_statuses(project_ids)
          aggregated_statuses = setting_based_statuses.filter_map do |setting_status|
            build_aggregated_status_for_setting(setting_status, existing_pipeline_statuses)
          end

          setting_based_statuses + aggregated_statuses
        end

        def build_aggregated_status_for_setting(setting_analyzer_status, existing_pipeline_statuses)
          project_id, setting_based_type = setting_analyzer_status.values_at('project_id', 'analyzer_type')
          aggregated_type = find_aggregated_type_for(setting_based_type)
          return unless aggregated_type

          other_type = ANALYZER_TYPES[TYPE_MAPPINGS[aggregated_type][:pipeline_type]]
          existing_pipeline_status = existing_pipeline_statuses[[project_id, other_type]]

          other_status = existing_pipeline_status&.status || STATUS_NOT_CONFIGURED
          wanted_aggregated_status = [setting_analyzer_status['status'], other_status].max

          build_status_record(project_id, setting_analyzer_status['traversal_ids'], ANALYZER_TYPES[aggregated_type],
            wanted_aggregated_status)
        end

        def find_aggregated_type_for(setting_based_type)
          TYPE_MAPPINGS.find do |_, config|
            ANALYZER_TYPES[config[:setting_type]] == setting_based_type
          end&.first
        end

        def upsert_analyzer_statuses(analyzer_statuses)
          return unless analyzer_statuses.any?

          values_sql = build_values_list(analyzer_statuses)
          sql = build_upsert_sql(values_sql)
          SecApplicationRecord.connection.execute(sql)
        end

        def analyzer_status_columns
          %w[project_id traversal_ids status analyzer_type last_call created_at updated_at].join(', ')
        end

        def build_values_list(analyzer_statuses)
          values_list = analyzer_statuses.map do |status_data|
            [
              status_data['project_id'],
              Arel.sql("ARRAY#{status_data['traversal_ids']}::bigint[]"),
              status_data['status'],
              status_data['analyzer_type'],
              format_timestamp(status_data['last_call']),
              format_timestamp(status_data['created_at']),
              format_timestamp(status_data['updated_at'])
            ]
          end

          Arel::Nodes::ValuesList.new(values_list).to_sql
        end

        def format_timestamp(timestamp)
          timestamp&.utc&.strftime('%Y-%m-%d %H:%M:%S.%N') || 'CURRENT_TIMESTAMP'
        end

        def build_upsert_sql(values_sql)
          <<~SQL
            INSERT INTO analyzer_project_statuses
              (#{analyzer_status_columns})
            #{values_sql}
            ON CONFLICT (project_id, analyzer_type) DO UPDATE SET
              status = EXCLUDED.status,
              last_call = EXCLUDED.last_call,
              updated_at = EXCLUDED.updated_at;
          SQL
        end
      end
    end
  end
end
