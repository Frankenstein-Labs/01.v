# frozen_string_literal: true

module Mcp
  class NamespaceAccessCacheResetWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :delayed
    feature_category :mcp_server
    urgency :low
    deduplicate :until_executed
    idempotent!

    defer_on_database_health_signal :gitlab_main, %i[members], 10.minutes

    def handle_event(event)
      group = Group.find_by_id(event.data[:group_id])
      return unless group

      user_ids = all_members_unique_by_user(group).pluck_user_ids
      return if user_ids.blank?

      User.clear_group_with_mcp_server_enabled_cache(user_ids)
    end

    private

    def all_members_unique_by_user(group)
      Member.from_union(
        [
          group.descendant_project_members_with_inactive.select(:user_id),
          group.members_with_descendants.select(:user_id)
        ],
        remove_duplicates: true
      ).select(:user_id)
    end
  end
end
