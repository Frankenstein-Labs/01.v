# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class BaseProjectPolicyService
      include Gitlab::Utils::StrongMemoize
      include Gitlab::InternalEventsTracking
      include ::Security::ScanResultPolicies::PolicyViolationCommentGenerator

      def initialize(project:, security_policy:)
        @project = project
        @security_policy = security_policy
      end

      private

      attr_reader :project, :security_policy

      def link_policy
        return if policy_disabled_or_scope_inapplicable?

        security_policy.transaction do
          security_policy.link_project!(project)

          if security_policy.type_pipeline_execution_schedule_policy?
            recreate_pipeline_execution_schedule_project_schedules(project, security_policy)
          elsif security_policy.type_scan_execution_policy?
            recreate_scan_execution_project_schedules(project, security_policy)
          end
        end

        return unless security_policy.type_approval_policy?

        create_approval_policy_rules
        sync_merge_request_rules
        sync_project_finding_enrichments

        track_branch_exceptions_bypass_settings
      end

      def unlink_policy(skip_delete_worker: false)
        security_policy.unlink_project!(project)

        if security_policy.type_approval_policy?
          delete_approval_policy_rules(security_policy.approval_policy_rules)
          enqueue_policy_violation_comment_updates unless skip_delete_worker

          sync_merge_request_rules

          unless skip_delete_worker
            rules = security_policy.approval_policy_rules
            return if Security::ApprovalPolicyRuleProjectLink.for_policy_rules(rules.select(:id)).exists?

            Security::DeleteApprovalPolicyRulesWorker.perform_in(1.minute, rules.map(&:id))
          end
        end

        if security_policy.type_pipeline_execution_schedule_policy?
          cancel_policy_pipelines_for_project
          security_policy
            .security_pipeline_execution_project_schedules
            .for_project(project)
            .delete_all
        elsif security_policy.type_scan_execution_policy?
          delete_scan_execution_project_schedules(project, security_policy)
        end
      end

      def sync_approval_policy_rules(approval_policy_rules = security_policy.approval_policy_rules.undeleted)
        update_approval_policy_rules(approval_policy_rules)
        sync_merge_request_rules
      end

      def sync_approval_policy_diff(policy_diff)
        created_rules, deleted_rules = find_changed_rules(policy_diff)
        security_policy.update_project_approval_policy_rule_links(project, created_rules, deleted_rules)

        if policy_diff.needs_complete_rules_refresh?
          rules = security_policy.approval_policy_rules.undeleted
          delete_approval_policy_rules(rules)
          create_approval_policy_rules(rules)
        else
          delete_approval_policy_rules(deleted_rules)
          create_approval_policy_rules(created_rules)

          if policy_diff.needs_rules_refresh?
            update_approval_policy_rules(security_policy.approval_policy_rules.undeleted)
          end
        end

        sync_merge_request_rules
      end

      def scope_applicable?
        security_policy.scope_applicable?(project)
      end

      def policy_disabled_or_scope_inapplicable?
        !security_policy.enabled || !scope_applicable?
      end

      def recreate_pipeline_execution_schedule_project_schedules(project, security_policy)
        Security::SecurityOrchestrationPolicies::PipelineExecutionPolicies::CreateProjectSchedulesService
          .new(project: project, security_policy: security_policy)
          .execute
      end

      def recreate_scan_execution_project_schedules(project, security_policy)
        Security::SecurityOrchestrationPolicies::ScanExecutionPolicies::CreateProjectSchedulesService
          .new(project: project, security_policy: security_policy)
          .execute
      end

      def delete_scan_execution_project_schedules(project, security_policy)
        return if Feature.disabled?(:scan_execution_policy_project_schedule_creation, project)

        security_policy
          .scan_execution_project_schedules
          .for_project(project)
          .delete_all
      end

      def cancel_policy_pipelines_for_project
        return unless cancel_pipelines_feature_enabled?

        Security::PipelineExecutionPolicies::CancelPolicyPipelinesWorker.perform_async(
          security_policy.id,
          project.id
        )
      end

      def cancel_pipelines_feature_enabled?
        policy_configuration = security_policy.security_orchestration_policy_configuration

        Feature.enabled?(
          :cancel_pipelines_when_policy_disabled,
          policy_configuration.namespace || policy_configuration.project.namespace
        )
      end

      def track_branch_exceptions_bypass_settings
        return unless security_policy.bypass_settings.branches.any?

        track_internal_event('check_branch_exceptions_bypass_settings_for_approval_policy', project: project)
      end

      def sync_merge_request_rules
        Security::SecurityOrchestrationPolicies::SyncMergeRequestsService.new(
          project: project, security_policy: security_policy
        ).execute
      end

      def enqueue_policy_violation_comment_updates
        merge_requests = project.merge_requests.opened
        # When this policy disables the bot message, only update MRs that already
        # have a policy bot comment (to refresh/clear it). MRs without an existing
        # comment have nothing to do.
        if security_policy.approval_policy.bot_message_disabled?
          merge_requests = merge_requests.with_policy_bot_comment(project)
        end

        merge_requests.each_batch do |batch|
          Security::GeneratePolicyViolationCommentWorker.perform_bulk(batch.map { |mr| [mr.id] })
        end
      end

      def sync_project_finding_enrichments
        return unless security_policy.has_enrichment_filters?

        Security::ScanResultPolicies::SyncProjectFindingEnrichmentsWorker
          .perform_async(project.id, security_policy.id)
      end

      def delete_approval_policy_rules(approval_policy_rules = security_policy.approval_policy_rules)
        Security::ScanResultPolicies::ApprovalRules::DeleteService.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rules: approval_policy_rules
        ).execute
      end

      def update_approval_policy_rules(approval_policy_rules = security_policy.approval_policy_rules.undeleted)
        Security::ScanResultPolicies::ApprovalRules::UpdateService.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rules: approval_policy_rules,
          author: approval_policy_author
        ).execute
      end

      def create_approval_policy_rules(approval_policy_rules = security_policy.approval_policy_rules.undeleted)
        Security::ScanResultPolicies::ApprovalRules::CreateService.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rules: approval_policy_rules,
          author: approval_policy_author
        ).execute
      end

      def find_changed_rules(policy_diff)
        created_rules = find_policy_rules(policy_diff.rules_diff.created.map(&:id))
        deleted_rules = find_policy_rules(policy_diff.rules_diff.deleted.map(&:id))

        [created_rules, deleted_rules]
      end

      def find_policy_rules(policy_rule_ids)
        security_policy.approval_policy_rules.id_in(policy_rule_ids)
      end

      def approval_policy_author
        security_policy.security_orchestration_policy_configuration.policy_last_updated_by
      end
      strong_memoize_attr :approval_policy_author
    end
  end
end
