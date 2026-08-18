# frozen_string_literal: true

module Security
  module ScanResultPolicies
    class UnblockPendingMergeRequestViolationsWorker
      include ApplicationWorker
      include ::Security::ScanResultPolicies::PolicyLogger

      idempotent!
      data_consistency :sticky
      deduplicate :until_executing, including_scheduled: true
      feature_category :security_policy_management

      def perform(pipeline_id)
        pipeline = ::Ci::Pipeline.find_by_id(pipeline_id) || return
        project = pipeline.project
        return unless project.licensed_feature_available?(:security_orchestration_policies)

        pipeline.opened_merge_requests_with_head_sha.each do |merge_request|
          skip_policy_evaluation(merge_request)
        end
      end

      private

      def skip_policy_evaluation(merge_request)
        violations = merge_request.running_scan_result_policy_violations
        return if violations.blank?

        approval_rules = merge_request.approval_rules.report_approver
                                      .for_approval_policy_rules(violations.map(&:approval_policy_rule_id))
        return if approval_rules.blank?

        evaluation = Security::SecurityOrchestrationPolicies::PolicyRuleEvaluationService.new(merge_request)
        approval_rules.each { |rule| evaluation.skip!(rule) }
        evaluation.save
        log_policy_evaluation('unblock_pending_violations',
          'Policy evaluation timed out, skipping and requiring approvals',
          project: merge_request.project, merge_request_id: merge_request.id, approval_rules: approval_rules)
      end
    end
  end
end
