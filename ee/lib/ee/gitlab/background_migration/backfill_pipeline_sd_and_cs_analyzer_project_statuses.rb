# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillPipelineSdAndCsAnalyzerProjectStatuses
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        TYPE_MAPPING = {
          6 => 12,  # secret_detection -> secret_detection_pipeline_based
          5 => 13   # container_scanning -> container_scanning_pipeline_based
        }.freeze
        class AnalyzerProjectStatus < ::SecApplicationRecord
          self.table_name = 'analyzer_project_statuses'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            statuses_to_clone = sub_batch.where(analyzer_type: TYPE_MAPPING.keys)
            next if statuses_to_clone.blank?

            records_to_insert = statuses_to_clone.map do |analyzer_status|
              analyzer_status.attributes.except('id', 'created_at', 'updated_at', 'analyzer_type').merge(
                'analyzer_type' => TYPE_MAPPING[analyzer_status.analyzer_type],
                'created_at' => Time.current,
                'updated_at' => Time.current
              )
            end

            AnalyzerProjectStatus.insert_all(records_to_insert, unique_by: [:project_id, :analyzer_type])
          end
        end
      end
    end
  end
end
