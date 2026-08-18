# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      # Backfills subscription_user_add_on_assignment_versions for assignments created before PaperTrail was added
      #
      # This migration creates version records for user add-on assignments that were created
      # before PaperTrail versioning was introduced. This ensures all assignments have proper version tracking
      # except for the ones that got revoked before that date as they get deleted after 14 days
      #
      # The migration:
      # 1. Finds assignments without version records
      # 2. Excludes assignments that already have version records
      # 3. Creates version records mimicking what PaperTrail would have created
      module BackfillSubscriptionUserAddOnAssignmentVersions
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        class Namespace < ::Gitlab::Database::Migration[2.2]::MigrationRecord
          self.table_name = 'namespaces'
          self.inheritance_column = :_type_disabled

          def traversal_path(with_organization: false)
            ids = traversal_ids.clone

            ids.prepend(organization_id) if with_organization

            "#{ids.join('/')}/"
          end
        end

        prepended do
          feature_category :value_stream_management
          operation_name :backfill_subscription_user_add_on_assignments_pre_papertrail
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            backfill_versions_for_batch(sub_batch)
          end
        end

        private

        def backfill_versions_for_batch(assignment_batch)
          assignments_data = fetch_assignments_without_versions(assignment_batch)
          return if assignments_data.empty?

          insert_version_records(assignments_data)
        end

        def fetch_assignments_without_versions(assignment_batch) # rubocop:disable Metrics/MethodLength -- method length is due to query with different cases
          query = <<~SQL
            SELECT ua.id, ua.add_on_purchase_id, ua.user_id, ua.created_at,
                  ua.updated_at, ua.organization_id,
                  ap.namespace_id, ao.name as add_on_name
            FROM subscription_user_add_on_assignments ua
              INNER JOIN subscription_add_on_purchases ap ON ua.add_on_purchase_id = ap.id
              INNER JOIN subscription_add_ons ao ON ap.subscription_add_on_id = ao.id
              LEFT JOIN subscription_user_add_on_assignment_versions v ON ua.id = v.item_id
              WHERE ua.id IN (#{assignment_batch.select(:id).to_sql})
                    AND (
                    -- Case 1: No version at all
                    NOT EXISTS (
                      SELECT 1 FROM subscription_user_add_on_assignment_versions v
                      WHERE v.item_id = ua.id
                    )
                    OR
                    -- Case 2: Has 'destroy' event, but not 'create' event
                    (
                      EXISTS (
                        SELECT 1 FROM subscription_user_add_on_assignment_versions v
                        WHERE v.item_id = ua.id AND v.event = 'destroy'
                      )
                      AND NOT EXISTS (
                        SELECT 1 FROM subscription_user_add_on_assignment_versions v
                        WHERE v.item_id = ua.id AND v.event = 'create'
                      )
                    )
                  )
          SQL
          assignments_data = connection.execute(query).to_a

          namespace_ids = assignments_data.filter_map { |a| a['namespace_id'] }
          namespaces_by_id = Namespace.where(id: namespace_ids).index_by(&:id)

          assignments_data.map do |assignment|
            if assignment['namespace_id']
              namespace = namespaces_by_id[assignment['namespace_id']]
              assignment['path'] =
                namespace&.traversal_path(with_organization: false) || "#{assignment['organization_id']}/"
            else
              assignment['path'] = "#{assignment['organization_id']}/"
            end

            assignment
          end
        end

        def insert_version_records(assignments)
          return if assignments.empty?

          values = assignments.filter_map do |assignment|
            build_version_record_values(assignment)
          end

          return if values.empty?

          insert_sql = <<~SQL
          INSERT INTO subscription_user_add_on_assignment_versions
          (organization_id, item_id, purchase_id, user_id, created_at,
           item_type, event, namespace_path, add_on_name, whodunnit, object)
          VALUES #{values.join(', ')}
          SQL

          connection.execute(insert_sql)
        end

        def build_version_record_values(assignment)
          organization_id = assignment['organization_id']
          namespace_path = assignment['path']

          object_data = {
            id: assignment['id'],
            add_on_purchase_id: assignment['add_on_purchase_id'],
            user_id: assignment['user_id'],
            created_at: assignment['created_at'],
            updated_at: assignment['updated_at'],
            organization_id: organization_id
          }

          "(#{organization_id}, #{assignment['id']}, #{assignment['add_on_purchase_id']}, " \
            "#{assignment['user_id']}, '#{assignment['created_at']}', " \
            "'GitlabSubscriptions::UserAddOnAssignment', 'create', " \
            "'#{namespace_path}', '#{assignment['add_on_name']}', " \
            "'backfill_migration', '#{connection.quote_string(object_data.to_json)}')"
        end
      end
    end
  end
end
