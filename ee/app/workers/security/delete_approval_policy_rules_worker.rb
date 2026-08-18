# frozen_string_literal: true

module Security
  class DeleteApprovalPolicyRulesWorker
    include ApplicationWorker

    ProjectLinkExistsError = Class.new(StandardError)

    feature_category :security_policy_management
    data_consistency :sticky
    deduplicate :until_executed
    idempotent!

    def perform(approval_policy_rule_ids)
      if Security::ApprovalPolicyRuleProjectLink.for_policy_rules(approval_policy_rule_ids).exists?
        # Raising an error here will make sure that the worker is retried.
        raise ProjectLinkExistsError, "Approval policy rules are still linked to projects"
      end

      Security::ApprovalPolicyRule.id_in(approval_policy_rule_ids).deleted.delete_all
    end
  end
end
