# frozen_string_literal: true

module EE
  module MergeRequests
    module AfterCreateService
      extend ::Gitlab::Utils::Override

      APPROVERS_NOTIFICATION_DELAY = 10.seconds

      override :prepare_merge_request
      def prepare_merge_request(merge_request)
        super

        if current_user.project_bot?
          log_audit_event(merge_request, 'merge_request_created_by_project_bot',
            "Created merge request #{merge_request.title}")
        end

        record_onboarding_progress(merge_request)
        merge_request.schedule_policy_synchronization
        schedule_approval_notifications(merge_request)
        schedule_duo_code_review(merge_request)
        track_usage_event if merge_request.project.has_approval_policy_rules?
        audit_security_policy_branch_bypass(merge_request)
        publish_event(merge_request)
      end

      private

      def publish_event(merge_request)
        ::Gitlab::EventStore.publish(
          ::MergeRequests::CreatedEvent.new(data: {
            merge_request_id: merge_request.id
          })
        )
      end

      def record_onboarding_progress(merge_request)
        ::Onboarding::ProgressService
          .new(merge_request.target_project.namespace).execute(action: :merge_request_created)
      end

      def schedule_approval_notifications(merge_request)
        ::MergeRequests::NotifyApproversWorker.perform_in(APPROVERS_NOTIFICATION_DELAY, merge_request.id)
      end

      # NOTE: If it was requested, Duo Code Review needs to be triggered after merge_request_diff gets created.
      def schedule_duo_code_review(merge_request)
        return unless merge_request.reviewers.duo_code_review_bot.any?

        request_duo_code_review(merge_request)
      end

      def track_usage_event
        ::Gitlab::UsageDataCounters::HLLRedisCounter.track_event(
          'users_creating_merge_requests_with_security_policies',
          values: current_user.id
        )
      end
    end
  end
end
