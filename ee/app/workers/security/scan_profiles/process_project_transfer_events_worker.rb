# frozen_string_literal: true

module Security
  module ScanProfiles
    class ProcessProjectTransferEventsWorker
      include Gitlab::EventStore::Subscriber
      include Gitlab::ExclusiveLeaseHelpers

      idempotent!
      data_consistency :sticky
      feature_category :security_testing_configuration

      LEASE_TIMEOUT = 5.minutes

      def handle_event(event)
        return if event.data[:old_root_namespace_id] == event.data[:new_root_namespace_id]

        project = Project.find_by_id(event.data[:project_id])
        return unless project

        old_namespace_id = event.data[:old_namespace_id]
        process_with_lock(old_namespace_id) do
          remove_old_namespace_scan_profile_associations(project)
        end
      end

      private

      def process_with_lock(namespace_id)
        lease_key = Security::ScanProfiles.update_lease_key(namespace_id)

        in_lock(lease_key, ttl: LEASE_TIMEOUT, sleep_sec: 1.second) do
          yield
        end
      end

      def remove_old_namespace_scan_profile_associations(project)
        project.security_scan_profiles_projects.not_in_root_namespace(project.group&.root_ancestor).delete_all
      end
    end
  end
end
