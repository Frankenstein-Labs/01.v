# frozen_string_literal: true

module EE
  module MergeRequests
    module RefreshService
      extend ::Gitlab::Utils::Override

      private

      override :refresh_merge_requests!
      def refresh_merge_requests!
        check_merge_train_status

        super

        remove_requested_changes
      end

      override :execute_async_workers
      def execute_async_workers
        super

        ::MergeRequests::Refresh::ApprovalWorker.perform_async(
          project.id,
          current_user.id,
          push.oldrev,
          push.newrev,
          push.ref
        )
      end

      override :abort_auto_merges?
      def abort_auto_merges?(merge_request)
        return true if merge_request.merge_train_car

        super
      end

      # rubocop:disable Gitlab/ModuleWithInstanceVariables
      def check_merge_train_status
        return unless @push.branch_updated?

        MergeTrains::CheckStatusService.new(project, current_user)
          .execute(project, @push.branch_name, @push.newrev)
      end

      def merge_requests_for_target_branch(reload: false, mr_states: [:opened])
        @target_merge_requests = nil if reload
        @target_merge_requests ||= project.merge_requests
          .with_state(mr_states)
          .by_target_branch(push.branch_name)
          .including_merge_train
      end
      # rubocop:enable Gitlab/ModuleWithInstanceVariables

      def remove_requested_changes
        return unless project.feature_available?(:requested_changes_block_merge_request)

        update_reviewer_service = ::MergeRequests::UpdateReviewerStateService
          .new(project: project, current_user: current_user)

        merge_requests_for_source_branch
          .select(&:merge_requests_disable_committers_approval?)
          .each do |merge_request|
            merge_request.destroy_requested_changes(current_user)
            update_reviewer_service.execute(merge_request, 'unreviewed')
          end
      end

      override :schedule_duo_code_review
      def schedule_duo_code_review(merge_request)
        return unless merge_request.project.auto_duo_code_review_enabled
        return if merge_request.draft?

        previous_diff = merge_request.previous_diff

        return unless previous_diff && previous_diff.empty?
        return unless merge_request.reviewers.duo_code_review_bot.any?

        # Attribute review to the MR author in this automatic flow. The git pusher
        # (current_user) may be a CI bot or another contributor unrelated to billing.
        # Reuse current_user object when they are the author to avoid an extra DB load.
        self.duo_review_user =
          current_user.id == merge_request.author_id ? current_user : merge_request.author
        request_duo_code_review(merge_request)
      end
    end
  end
end
