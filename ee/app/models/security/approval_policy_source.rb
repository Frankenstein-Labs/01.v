# frozen_string_literal: true

module Security
  # TODO: Remove this adapter once the `deprecate_scan_result_policies` feature flag
  # is fully enabled and `Security::ScanResultPolicyRead` is dropped. Callers should
  # then interact with `Security::ApprovalPolicyRule` directly.
  class ApprovalPolicySource
    include ::Gitlab::Utils::StrongMemoize

    DELEGATED_METHODS = %i[
      fail_open?
      newly_detected?
      only_newly_detected_licenses?
      bot_message_disabled?
      unblock_rules_using_execution_policies?
      vulnerability_age
      vulnerability_attributes
      commits_any?
      commits_unsigned?
      prevent_approval_by_author?
      prevent_approval_by_commit_author?
      match_on_inclusion_license
    ].freeze

    delegate(*DELEGATED_METHODS, to: :delegation_target, allow_nil: true)

    def initialize(project:, action_idx:, scan_result_policy_read: nil, approval_policy_rule: nil)
      @project = project
      @action_idx = action_idx
      @scan_result_policy_read = scan_result_policy_read
      @approval_policy_rule = approval_policy_rule
    end

    def has_source?
      delegation_target.present?
    end

    def resolved_approval_policy_rule
      if use_approval_policy_rule?
        approval_policy_rule
      else
        scan_result_policy_read&.approval_policy_rule
      end
    end
    strong_memoize_attr :resolved_approval_policy_rule

    def scan_result_policy_id
      scan_result_policy_read&.id
    end

    def approval_policy_rule_id
      approval_policy_rule&.id
    end

    def id
      delegation_target&.id
    end

    delegate :orchestration_policy_idx, :rule_idx, to: :scan_result_policy_read, allow_nil: true

    def role_approvers
      if use_approval_policy_rule?
        approval_policy_rule.role_approvers(action_idx: action_idx)
      else
        scan_result_policy_read&.role_approvers || []
      end
    end
    strong_memoize_attr :role_approvers

    def custom_roles
      if use_approval_policy_rule?
        approval_policy_rule.custom_roles(action_idx: action_idx)
      else
        scan_result_policy_read&.custom_roles || []
      end
    end
    strong_memoize_attr :custom_roles

    def custom_role_ids_with_permission
      if use_approval_policy_rule?
        approval_policy_rule.custom_role_ids_with_permission(project: project, action_idx: action_idx)
      else
        scan_result_policy_read&.custom_role_ids_with_permission || []
      end
    end

    def license_states
      if use_approval_policy_rule?
        approval_policy_rule.license_states || []
      else
        scan_result_policy_read&.license_states || []
      end
    end

    def licenses
      if use_approval_policy_rule?
        approval_policy_rule.licenses || {}
      else
        scan_result_policy_read&.licenses || {}
      end
    end

    def policy_name(rule_name)
      resolved_approval_policy_rule&.security_policy&.name || rule_name.gsub(/\s\d+\z/, '')
    end

    def warn_mode_policy?
      resolved_approval_policy_rule&.security_policy&.warn_mode? || false
    end

    def security_report_time_window
      resolved_approval_policy_rule&.security_policy&.security_report_time_window
    end

    def scanner_configurations
      resolved_rule = resolved_approval_policy_rule
      return unless resolved_rule&.type_scan_finding?

      rule_obj = resolved_rule.rule
      return unless rule_obj.has_scanner_overrides?

      rule_obj.scanner_configurations.map(&:to_h)
    end

    def use_approval_policy_rule?
      approval_policy_rule.present? && Feature.enabled?(:deprecate_scan_result_policies, project)
    end
    strong_memoize_attr :use_approval_policy_rule?

    private

    attr_reader :project, :scan_result_policy_read, :approval_policy_rule, :action_idx

    def delegation_target
      use_approval_policy_rule? ? approval_policy_rule : scan_result_policy_read
    end
    strong_memoize_attr :delegation_target
  end
end
