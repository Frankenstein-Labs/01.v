# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillEmptyProjectsInSecurityInventoryFilters
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class SecurityInventoryFilters < ::SecApplicationRecord
          self.table_name = 'security_inventory_filters'
        end

        class Project < ::ApplicationRecord
          self.table_name = 'projects'
        end

        class Namespace < ::ApplicationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled
        end

        class AnalyzerNamespaceStatus < ::SecApplicationRecord
          self.table_name = 'analyzer_namespace_statuses'
        end

        prepended do
          operation_name :backfill_empty_projects_in_security_inventory_filters
          feature_category :security_asset_inventories
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            process_projects(sub_batch)
          end
        end

        private

        def process_projects(project_batch)
          project_data = fetch_project_data_with_namespaces(project_batch)
          return if project_data.empty?

          root_namespace_ids_with_status = fetch_root_namespace_ids_with_status(project_data)
          return if root_namespace_ids_with_status.empty?

          records_to_insert = build_records(project_data, root_namespace_ids_with_status)
          return if records_to_insert.empty?

          SecurityInventoryFilters.insert_all(records_to_insert, unique_by: :project_id, returning: false)
        end

        def fetch_project_data_with_namespaces(project_batch)
          project_batch
            .joins("INNER JOIN namespaces ON namespaces.id = projects.project_namespace_id")
            .pluck('projects.id', 'projects.name', 'projects.archived', 'namespaces.traversal_ids')
        end

        def fetch_root_namespace_ids_with_status(project_data)
          root_namespace_ids = extract_root_namespace_ids(project_data)
          return [] if root_namespace_ids.empty?

          AnalyzerNamespaceStatus
            .where(namespace_id: root_namespace_ids)
            .where("array_length(traversal_ids, 1) = 1")
            .pluck(:namespace_id)
            .to_set
        end

        def extract_root_namespace_ids(project_data)
          project_data.filter_map { |_, _, _, traversal_ids| traversal_ids&.first }.uniq
        end

        def build_records(project_data, root_namespace_ids_with_status)
          project_data.filter_map do |project_id, name, archived, traversal_ids|
            next if name.blank?
            next if traversal_ids.blank? || traversal_ids.length < 2

            root_namespace_id = traversal_ids.first
            next unless root_namespace_ids_with_status.include?(root_namespace_id)

            {
              project_id: project_id,
              project_name: name,
              traversal_ids: traversal_ids[0..-2],
              archived: archived
            }
          end
        end
      end
    end
  end
end
