# frozen_string_literal: true

module MergeRequests
  module Mergeability
    class CheckSecurityPolicyViolationsService < CheckBaseService
      set_identifier :security_policy_violations
      set_failure_explanation N_('All security policy violations must be resolved.')
      set_description 'Checks whether the security policies are satisfied'

      def execute
        if !merge_request.project.licensed_feature_available?(:security_orchestration_policies) ||
            !merge_request_has_approval_policy_rules?
          return inactive
        end

        return checking if merge_request.running_scan_result_policy_violations.any?

        # When the MR is approved, it is considered to 'override' the violations
        if merge_request.failed_scan_result_policy_violations.any? && !merge_request.approved?
          failure
        elsif policy_violations_dismissed? || security_policy_bypassed?
          warning
        else
          success
        end
      end

      def skip?
        params[:skip_security_policy_check].present?
      end

      def cacheable?
        false
      end

      private

      def merge_request_has_approval_policy_rules?
        if Feature.enabled?(:deprecate_scan_result_policies, merge_request.project)
          merge_request.approval_rules.with_approval_policy_rule.any? ||
            merge_request.scan_result_policy_reads_through_approval_rules.any?
        else
          merge_request.scan_result_policy_reads_through_approval_rules.any?
        end
      end

      def policy_violations_dismissed?
        violations_with_dismissals = merge_request.scan_result_policy_violations
                                                  .with_security_policy_dismissal

        return false if violations_with_dismissals.empty?

        violations_with_dismissals.any?(&:dismissed?)
      end

      def security_policy_bypassed?
        merge_request.security_policies_with_bypass_settings.any? do |policy|
          policy.merge_request_bypassed?(merge_request)
        end
      end
    end
  end
end
