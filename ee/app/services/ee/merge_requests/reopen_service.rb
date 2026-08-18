# frozen_string_literal: true

module EE
  module MergeRequests
    module ReopenService
      extend ::Gitlab::Utils::Override

      override :execute
      def execute(merge_request)
        super.tap do
          # When the flag is enabled a reopen can be rejected (e.g. a branch no longer
          # exists), leaving the merge request closed; only run the side effects when it
          # actually reopened. When the flag is off, keep the previous behaviour.
          next if !merge_request.open? &&
            ::Feature.enabled?(:prevent_reopen_merge_request_without_branch, merge_request.project)

          delete_approvals(merge_request)
          resync_policies(merge_request)
          audit_security_policy_branch_bypass(merge_request)

          if current_user.project_bot?
            log_audit_event(merge_request, 'merge_request_reopened_by_project_bot',
              "Reopened merge request #{merge_request.title}")
          end

          publish_event(merge_request)
        end
      end

      private

      def publish_event(merge_request)
        ::Gitlab::EventStore.publish(
          ::MergeRequests::ReopenedEvent.new(data: {
            merge_request_id: merge_request.id
          })
        )
      end

      def resync_policies(merge_request)
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        # Ensure that we re-create violations and require approvals if they were previously set as optional
        merge_request.synchronize_approval_rules_from_target_project
        merge_request.schedule_policy_synchronization
      end
    end
  end
end
