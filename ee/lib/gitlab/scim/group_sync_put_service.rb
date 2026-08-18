# frozen_string_literal: true

module Gitlab
  module Scim
    class GroupSyncPutService
      attr_reader :scim_group_uid, :members, :display_name

      def initialize(scim_group_uid:, members:, display_name:)
        @scim_group_uid = scim_group_uid
        @members = members
        @display_name = display_name
      end

      def execute
        sync_group_membership

        ServiceResponse.success
      end

      private

      def sync_group_membership
        return unless members.is_a?(Array)

        normalized_members = members.reject(&:blank?)
        target_user_ids = fetch_target_user_ids(normalized_members)

        ::Authn::SyncScimGroupMembersWorker.perform_async(scim_group_uid, target_user_ids, 'replace')
      end

      def fetch_target_user_ids(normalized_members)
        extern_uids = normalized_members.filter_map { |member| member[:value] }
        return [] if extern_uids.empty?

        scim_identities = ScimIdentity.for_instance.with_extern_uid(extern_uids)
        scim_identities.map(&:user_id)
      end
    end
  end
end
