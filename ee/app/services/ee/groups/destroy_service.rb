# frozen_string_literal: true

module EE
  module Groups
    module DestroyService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute
        with_scheduling_epic_cache_update do
          result = super
          next result if result.error?

          after_destroy(result[:group])
          result
        end
      end

      # Secrets manager cleanup is driven by the database. The FK on
      # `group_secrets_managers.group_id` is `ON DELETE CASCADE`, so
      # destroying the group also deletes the SM row, which fires the
      # `enqueue_gsm_deprovision_task_after_delete` trigger and inserts
      # a deprovision maintenance task with the snapshot ids read off
      # the SM's denormalized columns. The cron worker picks it up and
      # tears down OpenBao asynchronously. See gitlab-org/gitlab#600290.
      # Child groups and projects each fire their own destroy hook,
      # which triggers the same way.

      private

      # rubocop:disable CodeReuse/ActiveRecord
      def users_to_destroy
        group.service_accounts.pluck(:user_id) + super
      end
      # rubocop:enable CodeReuse/ActiveRecord

      def after_destroy(group)
        delete_dependency_proxy_blobs(group)

        return if group&.persisted?

        log_audit_event

        return unless ::Gitlab::Geo.primary? && group.group_wiki_repository

        group.group_wiki_repository.geo_handle_after_destroy
      end

      # rubocop:disable Scalability/BulkPerformWithContext
      def with_scheduling_epic_cache_update
        ids = group.parent_epic_ids_in_ancestor_groups

        group = yield

        ::Epics::UpdateCachedMetadataWorker.bulk_perform_in(
          1.minute,
          ids.each_slice(::Epics::UpdateCachedMetadataWorker::BATCH_SIZE).map { |ids| [ids] }
        )

        group
      end
      # rubocop:enable Scalability/BulkPerformWithContext

      def delete_dependency_proxy_blobs(group)
        # the blobs reference files that need to be destroyed that cascade delete
        # does not remove
        group.dependency_proxy_blobs.destroy_all # rubocop:disable Cop/DestroyAll
      end

      def log_audit_event
        audit_context = {
          name: 'group_destroyed',
          author: current_user,
          scope: group.root_ancestor,
          target: group,
          message: 'Group destroyed',
          target_details: group.full_path,
          additional_details: {
            remove: 'group'
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
