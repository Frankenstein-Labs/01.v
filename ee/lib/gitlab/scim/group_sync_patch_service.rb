# frozen_string_literal: true

module Gitlab
  module Scim
    class GroupSyncPatchService
      attr_reader :scim_group_uid, :operations

      def initialize(scim_group_uid:, operations:)
        @scim_group_uid = scim_group_uid
        @operations = operations
      end

      def execute
        operations.each do |operation|
          operation_type = operation[:op].to_s.downcase

          case operation_type
          when 'add'
            process_add_operation(operation)
          when 'remove'
            process_remove_operation(operation)
          end
        end

        ServiceResponse.success
      end

      private

      def process_add_operation(operation)
        case operation[:path].to_s.downcase
        when 'externalid'
          # NO-OP
          #
          # For now we just accept the externalId update but don't store it.
          # In some IdPs (e.g. Microsoft Entra), this is part of the group
          # sync provisioning cycle.
        when 'members'
          process_add_members(operation[:value])
        end
      end

      def process_remove_operation(operation)
        case operation[:path].to_s.downcase
        when 'members'
          process_remove_members(operation[:value])
        end
      end

      def process_add_members(members)
        return unless members.is_a?(Array)

        user_ids = collect_user_ids_from_members(members)
        return if user_ids.empty?

        ::Authn::SyncScimGroupMembersWorker.perform_async(scim_group_uid, user_ids, 'add')
      end

      def process_remove_members(members)
        return unless members.is_a?(Array)

        user_ids = collect_user_ids_from_members(members)
        return if user_ids.empty?

        ::Authn::SyncScimGroupMembersWorker.perform_async(scim_group_uid, user_ids, 'remove')
      end

      def collect_user_ids_from_members(members)
        extern_uids = members.filter_map { |member| member[:value] }
        return [] if extern_uids.empty?

        identities = ScimIdentity.for_instance.with_extern_uid(extern_uids)
        identities.filter_map(&:user_id)
      end
    end
  end
end
