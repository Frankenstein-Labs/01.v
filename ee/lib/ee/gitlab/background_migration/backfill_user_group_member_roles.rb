# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillUserGroupMemberRoles
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_user_group_member_roles
          feature_category :permissions
          scope_to ->(relation) do
            relation.where.not(member_role_id: nil).where(source_type: 'Namespace', state: 0)
          end
        end

        UNIQUE_BY = %i[user_id group_id].freeze

        class UserGroupMemberRole < ::ApplicationRecord
          self.table_name = 'user_group_member_roles'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            members_with_member_role = sub_batch.map do |member|
              {
                user_id: member.user_id,
                group_id: member.source_id,
                member_role_id: member.member_role_id,
                shared_with_group_id: nil
              }
            end

            # members that have not accepted an invite have a nil user_id
            filtered_members = members_with_member_role.select { |member| member[:user_id] }

            # we have some duplicate records in the database because
            # we don't have a unique index on (user, source), so let's filter them out
            unique_members = filtered_members.uniq { |attr| attr.slice(*UNIQUE_BY) }

            UserGroupMemberRole.upsert_all(
              unique_members,
              returning: false,
              unique_by: UNIQUE_BY
            )
          end
        end
      end
    end
  end
end
