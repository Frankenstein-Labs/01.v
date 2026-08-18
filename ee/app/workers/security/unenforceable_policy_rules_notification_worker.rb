# frozen_string_literal: true

module Security
  class UnenforceablePolicyRulesNotificationWorker
    include ApplicationWorker

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    data_consistency :sticky
    concurrency_limit -> { 200 }
    feature_category :security_policy_management

    def perform(merge_request_id, params = {})
      merge_request = MergeRequest.find_by_id(merge_request_id)

      return unless merge_request

      project = merge_request.project
      return unless project.licensed_feature_available?(:security_orchestration_policies)

      return if !merge_request_has_approval_policy_rules?(merge_request) &&
        params['force_without_approval_rules'].blank?

      Security::UnenforceablePolicyRulesNotificationService.new(merge_request).execute
    end

    private

    def merge_request_has_approval_policy_rules?(merge_request)
      if Feature.enabled?(:deprecate_scan_result_policies, merge_request.project)
        merge_request.approval_rules.with_approval_policy_rule.any?
      else
        merge_request.approval_rules.with_scan_result_policy_read.any?
      end
    end
  end
end
