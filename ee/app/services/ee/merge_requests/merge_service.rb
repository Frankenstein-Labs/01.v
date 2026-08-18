# frozen_string_literal: true

module EE
  module MergeRequests
    module MergeService
      extend ::Gitlab::Utils::Override

      def after_merge
        MergeTrains::Car.insert_skip_merged_car_for(merge_request, current_user) if skipping_active_merge_train?

        super
      end

      def skipping_active_merge_train?
        params[:skip_merge_train] && project.merge_trains_skip_train_allowed?
      end

      private

      # Final approval re-check, performed inside MergeService#in_locked_state
      # immediately before the git merge. Approval is validated earlier during
      # #validate!, but that happens before the MR is locked; RemoveApprovalService
      # refuses to remove approvals once the MR is locked, so re-reading here (with a
      # fresh cache) guarantees the MR is still approved at the moment it is merged and
      # closes the unapprove-during-merge race.
      # https://gitlab.com/gitlab-org/gitlab/-/issues/604469
      override :commit
      def commit
        ensure_approved!

        super
      end

      def ensure_approved!
        return unless merge_request.approval_feature_available?

        merge_request.reset_approval_cache!

        raise_error('Merge request is not approved') unless merge_request.approved?
      end
    end
  end
end
