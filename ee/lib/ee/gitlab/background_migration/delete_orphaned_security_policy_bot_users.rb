# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module DeleteOrphanedSecurityPolicyBotUsers
        extend ::Gitlab::Utils::Override
        extend ActiveSupport::Concern

        prepended do
          operation_name :delete_orphaned_security_policy_bot_users
          feature_category :security_policy_management
        end

        override :perform
        def perform
          users_table = Arel::Table.new(:users)
          members_table = Arel::Table.new(:members)
          ghost_migrations_table = Arel::Table.new(:ghost_user_migrations)

          members_not_exists_query = Arel::Nodes::Not.new(
            Arel::Nodes::Exists.new(
              members_table.where(
                members_table[:user_id].eq(users_table[:id])
                  .and(members_table[:type].eq('ProjectMember'))
              )
            )
          )

          ghost_migrations_not_exists_query = Arel::Nodes::Not.new(
            Arel::Nodes::Exists.new(
              ghost_migrations_table
                .where(ghost_migrations_table[:user_id].eq(users_table[:id]))
            )
          )

          each_sub_batch do |sub_batch|
            orphaned_users = sub_batch
              .where(user_type: 10)
              .where(members_not_exists_query)
              .where(ghost_migrations_not_exists_query)

            orphaned_users.delete_all if orphaned_users.any?
          end
        end
      end
    end
  end
end
