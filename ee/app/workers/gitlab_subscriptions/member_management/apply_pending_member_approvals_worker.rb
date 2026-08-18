# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    class ApplyPendingMemberApprovalsWorker
      include Gitlab::EventStore::Subscriber
      include GitlabSubscriptions::MemberManagement::PromotionManagementUtils

      feature_category :seat_cost_management
      data_consistency :always
      urgency :low

      idempotent!
      deduplicate :until_executed

      def handle_event(event)
        return unless member_promotion_management_enabled?

        member_user = User.find_by_id(event.data[:member_user_id])
        return unless member_user.present?

        return unless ::GitlabSubscriptions::MemberManagement::MemberApproval
                        .pending_member_approvals_for_user(member_user.id)
                        .exists?

        ::GitlabSubscriptions::MemberManagement::ProcessUserBillablePromotionService
          .new(member_user, nil, { status: :approved, skip_authorization: true }).execute
      end
    end
  end
end
