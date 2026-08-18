# frozen_string_literal: true

module Security
  module ScanProfiles
    class ProcessGroupTransferEventsWorker
      include Gitlab::EventStore::Subscriber

      idempotent!
      data_consistency :sticky
      feature_category :security_policy_management

      def handle_event(event)
        group_id = event.data[:group_id]
        old_root_namespace_id = event.data[:old_root_namespace_id]
        new_root_namespace_id = event.data[:new_root_namespace_id]
        return if old_root_namespace_id == new_root_namespace_id

        group = Group.find_by_id(group_id)
        return unless group

        if was_nested_group?(group_id, old_root_namespace_id) # Different root namespace - Only delete connections
          schedule_project_connections_cleanup(group_id)
        elsif became_nested_group?(group_id, new_root_namespace_id) # Was root and became nested - Delete profiles
          schedule_profiles_cleanup(group)
        end
      end

      private

      def was_nested_group?(group_id, old_root_namespace_id)
        old_root_namespace_id != group_id
      end

      def became_nested_group?(group_id, new_root_namespace_id)
        new_root_namespace_id != group_id
      end

      def schedule_project_connections_cleanup(group_id)
        Security::ScanProfiles::CleanOldNamespaceConnectionsWorker.perform_async(group_id, true)
      end

      def schedule_profiles_cleanup(group)
        profiles_ids = group.security_scan_profiles.scan_profile_ids
        return unless profiles_ids.any?

        Security::ScanProfiles::DeleteScanProfilesWorker.perform_async(profiles_ids, group.id)
      end
    end
  end
end
