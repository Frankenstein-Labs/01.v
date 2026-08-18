# frozen_string_literal: true

module Llm
  class NamespaceAccessCacheResetWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :delayed
    feature_category :ai_abstraction_layer
    urgency :low
    deduplicate :until_executed
    idempotent!

    def handle_event(event)
      members = members_for_event(event)
      return if members.blank?

      User.clear_group_with_ai_available_cache(members.pluck_user_ids)
    end

    private

    def members_for_event(event)
      case event
      when ::NamespaceSettings::AiRelatedSettingsChangedEvent
        group = Group.find_by_id(event.data[:group_id])
        return unless group && group.licensed_feature_available?(:ai_features)

        all_members_unique_by_user(group)
      when ::Members::MembersAddedEvent
        source = event.data[:source_type].constantize.find_by_id(event.data[:source_id])
        return unless source && source.licensed_feature_available?(:ai_features)

        source.members.created_after(User::GROUP_WITH_AI_ENABLED_CACHE_PERIOD.ago)
      end
    end

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
