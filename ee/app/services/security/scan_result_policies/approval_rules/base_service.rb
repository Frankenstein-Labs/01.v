# frozen_string_literal: true

module Security
  module ScanResultPolicies
    module ApprovalRules
      class BaseService
        include Gitlab::Utils::StrongMemoize
        include Gitlab::Loggable

        def initialize(project:, security_policy:, approval_policy_rules:, author:)
          @project = project
          @security_policy = security_policy
          @approval_policy_rules = approval_policy_rules
          @author = author
        end

        private

        attr_reader :project, :security_policy, :approval_policy_rules, :author

        def rule_params(approval_policy_rule, scan_result_policy_read, action_index = 0, approval_action = nil)
          ::Security::ScanResultPolicies::ApprovalRuleParamsBuilder.new(
            project: project,
            security_policy: security_policy,
            approval_policy_rule: approval_policy_rule,
            scan_result_policy_read: scan_result_policy_read,
            approval_action: approval_action,
            action_index: action_index,
            protected_branch_ids: protected_branch_ids(approval_policy_rule),
            author: author
          ).build
        end

        def scan_result_policy_read_params(approval_policy_rule, action_index = 0, approval_action = nil)
          ::Security::ScanResultPolicies::ScanResultPolicyReadParamsBuilder.new(
            project: project,
            security_policy: security_policy,
            approval_policy_rule: approval_policy_rule,
            approval_action: approval_action,
            action_index: action_index
          ).build
        end

        def protected_branch_ids(approval_policy_rule)
          service = Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project)
          rule_content = approval_policy_rule.content.deep_symbolize_keys
          applicable_branches = service.scan_result_branches([rule_content])
          overlap_enabled = Feature.enabled?(:wildcard_pattern_overlap_for_mrap, project)
          policy_matchers = if overlap_enabled
                              (rule_content[:branches] || []).map do |pattern|
                                RefMatcher.new(pattern)
                              end
                            else
                              []
                            end

          protected_branches = project.all_protected_branches.select do |protected_branch|
            # Existing: match via literal branch name intermediaries
            applicable_branches.any? { |branch| protected_branch.matches?(branch) } ||
              # New: direct pattern-to-pattern overlap check for wildcard matching
              policy_matchers.any? { |matcher| matcher.overlaps?(protected_branch.name) }
          end

          # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- protected branches will be limited
          protected_branches.pluck(:id)
          # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
        end

        def sync_license_scanning_rule(approval_policy_rule, scan_result_policy_read)
          return unless should_sync_license_rules?(approval_policy_rule)

          Security::SecurityOrchestrationPolicies::SyncLicensePolicyRuleService.new(
            project: project,
            security_policy: security_policy,
            approval_policy_rule: approval_policy_rule,
            scan_result_policy_read: scan_result_policy_read
          ).execute
        end

        def should_sync_license_rules?(approval_policy_rule)
          approval_policy_rule.type_license_finding? &&
            (approval_policy_rule.license_types.present? || approval_policy_rule.licenses.present?)
        end

        def project_approval_rules_map
          project
            .approval_rules
            .for_approval_policy_rules(approval_policy_rules)
            .each_with_object({}) do |item, result|
              result[item.approval_policy_rule_id] ||= {}
              result[item.approval_policy_rule_id][item.approval_policy_action_idx] = item
            end
        end

        def scan_result_policy_reads_map
          project
            .scan_result_policy_reads
            .for_approval_policy_rules(approval_policy_rules)
            .each_with_object({}) do |item, result|
              result[item.approval_policy_rule_id] ||= {}
              result[item.approval_policy_rule_id][item.action_idx] = item
            end
        end

        def log_service_failure(event, approval_policy_rule, scan_result_policy_read, action_index, errors)
          Gitlab::AppJsonLogger.debug(
            build_structured_payload(
              event: event,
              project_id: project.id,
              project_path: project.full_path,
              scan_result_policy_read_id: scan_result_policy_read.id,
              approval_policy_rule_id: approval_policy_rule.id,
              action_index: action_index,
              errors: errors
            )
          )
        end

        def approval_actions
          security_policy.policy_content[:actions]&.select do |action|
            action[:type] == Security::ScanResultPolicy::REQUIRE_APPROVAL
          end
        end
        strong_memoize_attr :approval_actions
      end
    end
  end
end
