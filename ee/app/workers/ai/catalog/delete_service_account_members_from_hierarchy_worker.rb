# frozen_string_literal: true

module Ai
  module Catalog
    class DeleteServiceAccountMembersFromHierarchyWorker
      include ApplicationWorker

      MemberDeletionError = Class.new(StandardError)

      feature_category :ai_abstraction_layer
      data_consistency :delayed
      urgency :low
      idempotent!

      defer_on_database_health_signal :gitlab_main, %i[user_members users], 10.minutes

      def perform(triggering_user_id, service_account_id, group_id, members_destroy_service_options = {})
        @triggering_user = User.find_by_id(triggering_user_id)
        @service_account = User.find_by_id(service_account_id)
        @group = Group.find_by_id(group_id)
        # Since we don't necessarily have a group membership in the top level group, we have to call the service for
        # each project individually, rather than using the built in subresource handling.
        @destroy_service_options = members_destroy_service_options.symbolize_keys.merge(skip_subresources: true)

        return if triggering_user.nil? || service_account.nil? || group.nil?

        memberships.find_each do |member|
          next if member_needed_for_flow?(member)

          Members::DestroyService.new(
            member,
            current_user: triggering_user,
            **destroy_service_options
          ).execute

          next if member.destroyed?

          error = "Could not delete member: #{member.errors.full_messages.to_sentence}"

          Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
            MemberDeletionError.new(error), { project_id: member.source_id, service_account_id: service_account.id }
          )
        end
      end

      private

      attr_reader :triggering_user, :service_account, :group, :destroy_service_options

      def member_needed_for_flow?(member)
        # source_id is a project for ProjectMember
        Ai::Catalog::ItemConsumer.exists_for_service_account_and_project_id?(service_account, member.source_id)
      end

      def memberships
        ::ProjectMember.in_hierarchy(group).with_user(service_account)
      end
    end
  end
end
