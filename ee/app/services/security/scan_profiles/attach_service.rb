# frozen_string_literal: true

module Security
  module ScanProfiles
    class AttachService
      include BaseServiceUtility
      include Gitlab::ExclusiveLeaseHelpers

      BATCH_SIZE = 500
      LEASE_TIMEOUT = 5.minutes
      RETRY_DELAY = 30.seconds
      LEASE_RETRY_WITH_TRAVERSAL = 5
      LEASE_WAIT_WITH_TRAVERSAL = 5.seconds
      LEASE_RETRY_WITHOUT_TRAVERSAL = 10
      LEASE_WAIT_WITHOUT_TRAVERSAL = 10.seconds

      def self.execute(...)
        new(...).execute
      end

      def initialize(group, scan_profile, current_user:, traverse_hierarchy: true, operation_id: nil)
        @group = group
        @scan_profile = scan_profile
        @current_user = current_user
        @traverse_hierarchy = traverse_hierarchy
        @operation_id = operation_id
        @errors = []
      end

      def execute
        return error('Scan profile does not belong to group hierarchy') unless valid_namespace?

        attach_profile_to_projects

        @errors.present? ? error(@errors) : success
      end

      private

      attr_reader :group, :scan_profile, :current_user, :traverse_hierarchy, :operation_id

      def valid_namespace?
        scan_profile.namespace_id == group.root_ancestor.id
      end

      def attach_profile_to_projects
        if traverse_hierarchy
          cursor = { current_id: group.id, depth: [group.id] }
          iterator = Gitlab::Database::NamespaceEachBatch.new(namespace_class: Group, cursor: cursor)

          iterator.each_batch(of: BATCH_SIZE) do |namespace_ids|
            namespace_ids.each do |namespace_id|
              process_namespace_with_lock(namespace_id)
            end
          end
        else
          process_namespace_with_lock(group.id)
        end
      end

      def process_namespace_with_lock(namespace_id)
        relation = Project.in_namespace(namespace_id).order_by_primary_key

        relation.each_batch(of: BATCH_SIZE) do |batch|
          insert_batch_with_lock(namespace_id, batch)
        end
      end

      def insert_batch_with_lock(namespace_id, batch)
        lease_key = "#{Security::ScanProfiles.update_lease_key(namespace_id)}:profile:#{scan_profile.id}"

        in_lock(lease_key, ttl: LEASE_TIMEOUT, **lock_retry_options) do
          result = Security::ScanProfiles::ProjectAttachService.execute(
            profile: scan_profile,
            current_user: current_user,
            projects: batch.to_a
          )

          @errors.concat(result[:errors]) if result[:errors].any?
        end
      rescue Gitlab::ExclusiveLeaseHelpers::FailedToObtainLockError => error
        handle_lock_failure(error, namespace_id)
      end

      def lock_retry_options
        return { retries: LEASE_RETRY_WITH_TRAVERSAL, sleep_sec: LEASE_WAIT_WITH_TRAVERSAL } if traverse_hierarchy

        { retries: LEASE_RETRY_WITHOUT_TRAVERSAL, sleep_sec: LEASE_WAIT_WITHOUT_TRAVERSAL }
      end

      def handle_lock_failure(error, namespace_id)
        raise error unless traverse_hierarchy

        Security::ScanProfiles::AttachWorker.perform_in(
          RETRY_DELAY, namespace_id, scan_profile.id, current_user.id, operation_id, false
        )
      end
    end
  end
end
