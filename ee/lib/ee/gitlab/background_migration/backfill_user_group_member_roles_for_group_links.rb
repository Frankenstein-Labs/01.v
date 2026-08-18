# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillUserGroupMemberRolesForGroupLinks
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_user_group_member_roles_on_group_links
          feature_category :permissions
          scope_to ->(relation) do
            relation
              .where(source_type: 'Namespace', state: 0)
              .where.not(user_id: nil)
              .where(requested_at: nil)
          end
        end

        UNIQUE_BY = %i[user_id group_id shared_with_group_id].freeze

        class UserGroupMemberRole < ::ApplicationRecord
          self.table_name = 'user_group_member_roles'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            user_group_member_roles = fetch_user_group_member_roles(sub_batch)

            unique_members = user_group_member_roles.uniq { |attr| attr.slice(*UNIQUE_BY) }

            UserGroupMemberRole.upsert_all(
              unique_members,
              returning: false,
              unique_by: UNIQUE_BY
            )
          end
        end

        private

        def fetch_user_group_member_roles(sub_batch)
          query = <<~SQL
            WITH sub_batch AS (#{sub_batch.limit(sub_batch_size).to_sql}),
            computed_roles AS (
              SELECT m.user_id,
                ggl.shared_group_id AS group_id,
                CASE
                  WHEN m.access_level > ggl.group_access THEN ggl.member_role_id
                  WHEN m.access_level < ggl.group_access THEN m.member_role_id
                  WHEN ggl.member_role_id IS NULL THEN NULL
                  ELSE m.member_role_id
                END AS member_role_id,
                ggl.shared_with_group_id
              FROM sub_batch m
              INNER JOIN group_group_links ggl on ggl.shared_with_group_id = m.source_id
              WHERE (m.member_role_id IS NOT NULL OR ggl.member_role_id IS NOT NULL)
            )
            SELECT * FROM computed_roles WHERE member_role_id IS NOT NULL
          SQL

          results = connection.select_all query
          results.to_a.map(&:symbolize_keys)
        end
      end
    end
  end
end
