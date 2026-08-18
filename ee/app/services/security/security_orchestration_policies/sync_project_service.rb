# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncProjectService < BaseProjectPolicyService
      def initialize(security_policy:, project:, policy_changes:)
        super(security_policy: security_policy, project: project)
        @policy_changes = policy_changes
      end

      def execute
        if policy_diff.any_changes?
          # Existing policy has been changed.
          sync_policy_changes
        else
          # Policy has just been created, link it.
          link_policy
        end

        schedule_warn_mode_audit_events_worker
      end

      private

      attr_reader :policy_changes

      def policy_diff
        Security::SecurityOrchestrationPolicies::PolicyDiff::Diff.from_json(
          policy_changes[:diff], policy_changes[:rules_diff]
        )
      end
      strong_memoize_attr :policy_diff

      def sync_policy_changes
        return unlink_policy if should_unlink_policy?
        return link_policy if should_link_policy?
        return if policy_disabled_or_scope_inapplicable?

        if security_policy.type_approval_policy?
          sync_approval_policy_diff(policy_diff)
          sync_project_finding_enrichments
          track_branch_exceptions_bypass_settings
        elsif security_policy.type_pipeline_execution_schedule_policy?
          cancel_policy_pipelines_for_project if policy_diff.schedule_snoozed?
          recreate_pipeline_execution_schedule_project_schedules(project, security_policy)
        elsif security_policy.type_scan_execution_policy?
          recreate_scan_execution_project_schedules(project, security_policy)
        end
      end

      def should_unlink_policy?
        policy_status_changed_and_disabled? || policy_scope_changed_and_unscoped?
      end

      def should_link_policy?
        policy_status_changed_and_enabled? || policy_scope_changed_and_scoped? || policy_not_linked_to_project?
      end

      def policy_status_changed_and_enabled?
        policy_diff.status_changed? && security_policy.enabled?
      end

      def policy_status_changed_and_disabled?
        policy_diff.status_changed? && !security_policy.enabled?
      end

      def policy_scope_changed_and_scoped?
        policy_diff.scope_changed? && scope_applicable?
      end

      def policy_not_linked_to_project?
        scope_applicable? && !security_policy.linked_to_project?(project)
      end

      def policy_scope_changed_and_unscoped?
        policy_diff.scope_changed? && !scope_applicable?
      end

      def schedule_warn_mode_audit_events_worker
        return unless security_policy.type_approval_policy? && security_policy.warn_mode?
        return if policy_disabled_or_scope_inapplicable?

        Security::ScanResultPolicies::CreateProjectWarnModePushSettingsAuditEventsWorker
          .perform_async(project.id, security_policy.id)
      end
    end
  end
end
