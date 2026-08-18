# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class PersistPolicyService
      include BaseServiceUtility
      include Gitlab::Loggable
      include Gitlab::Utils::StrongMemoize
      include Gitlab::InternalEventsTracking

      POLICY_TYPE_ALIAS = {
        scan_result_policy: :approval_policy
      }.freeze

      def initialize(policy_configuration:, policies:, policy_type:, force_resync: false)
        @policy_configuration = policy_configuration
        @policies = policies
        @policy_type = POLICY_TYPE_ALIAS[policy_type] || policy_type
        @force_resync = force_resync
        raise ArgumentError, "unrecognized policy_type" unless Security::Policy.types.symbolize_keys.key?(@policy_type)
      end

      def execute
        Gitlab::AppJsonLogger.debug(
          build_structured_payload(
            security_orchestration_policy_configuration_id: policy_configuration.id,
            policy_type: policy_type,
            message: 'Starting security policy persistence'
          )
        )

        new_policies, deleted_policies, policies_changes, rearranged_policies = policy_configuration.policy_changes(
          db_policies, policies
        )
        created_policies = []
        updated_policies = []

        ApplicationRecord.transaction do
          mark_policies_for_deletion(deleted_policies)
          update_rearranged_policies(rearranged_policies)
          created_policies = create_policies(new_policies)
          updated_policies = update_policies(policies_changes)
        end

        Gitlab::AppJsonLogger.debug(
          build_structured_payload(
            security_orchestration_policy_configuration_id: policy_configuration.id,
            policy_type: policy_type,
            new_policies_count: new_policies.size,
            deleted_policies_count: deleted_policies.size,
            updated_policies_count: policies_changes.size,
            rearranged_policies_count: rearranged_policies.size,
            message: 'security policy persisted'
          )
        )

        if collect_audit_events_for_the_config?
          CollectPoliciesAuditEvents.new(
            policy_configuration: policy_configuration,
            created_policies: created_policies,
            updated_policies: updated_policies,
            deleted_policies: deleted_policies
          ).execute
        end

        track_approval_policy_feature_usage(:create, created_policies)
        track_approval_policy_feature_usage(:update, updated_policies)

        Security::SecurityOrchestrationPolicies::EventPublisher.new(
          db_policies: db_policies.undeleted,
          created_policies: created_policies,
          policies_changes: policies_changes,
          deleted_policies: deleted_policies,
          force_resync: force_resync
        ).publish
      end

      private

      attr_reader :policy_configuration, :policies, :policy_type, :force_resync

      delegate :security_policies, to: :policy_configuration

      def db_policies
        policy_configuration.security_policies.undeleted.merge(relation_scope)
      end
      strong_memoize_attr :db_policies

      def create_policies(new_policies)
        new_policies.map do |policy_hash, index|
          Security::Policy.upsert_policy(policy_type, security_policies, policy_hash, index, policy_configuration)
        end
      end

      def update_policies(policies_changes)
        return [] if policies_changes.empty?

        Security::SecurityOrchestrationPolicies::UpdateSecurityPoliciesService.new(
          policies_changes: policies_changes
        ).execute
      end

      def mark_policies_for_deletion(deleted_policies)
        return if deleted_policies.empty?

        max_index = all_db_policies.next_deletion_index
        deleted_policies.each_with_index do |policy, index|
          new_index = max_index + index
          policy.update!(policy_index: -new_index, enabled: false)
        end
      end

      # Updates in two steps to avoid unique constraint violations
      def update_rearranged_policies(rearranged_policies)
        return if rearranged_policies.empty?

        temp_index_start = all_db_policies.next_deletion_index
        rearranged_policies.each_with_index do |(policy, _), temp_index|
          policy.update!(policy_index: -(temp_index_start + temp_index))
        end

        rearranged_policies.each do |policy, new_index|
          policy.update!(policy_index: new_index)
        end
      end

      # Includes soft-deleted policies (negative policy_index) so assigned negative
      # indexes never collide with them. See https://gitlab.com/gitlab-org/gitlab/-/issues/600862
      def all_db_policies
        security_policies.merge(relation_scope)
      end

      def relation_scope
        case policy_type
        when :approval_policy then Security::Policy.type_approval_policy
        when :scan_execution_policy then Security::Policy.type_scan_execution_policy
        when :pipeline_execution_policy then Security::Policy.type_pipeline_execution_policy
        when :vulnerability_management_policy then Security::Policy.type_vulnerability_management_policy
        when :pipeline_execution_schedule_policy then Security::Policy.type_pipeline_execution_schedule_policy
        when :dependency_firewall_policy then Security::Policy.type_dependency_firewall_policy
        end
      end

      def collect_audit_events_for_the_config?
        policy_configuration.first_configuration_for_the_management_project?
      end

      def track_approval_policy_feature_usage(action, policies)
        return unless policy_type == :approval_policy
        return if policies.empty?

        features = detect_rule_features(policies)

        track_policy_event("approval_policy_with_enrichment_filters", action) if features[:enrichment_filters]
        track_policy_event("approval_policy_with_atomic_scanner_rule", action) if features[:scanner_overrides]
      end

      def detect_rule_features(policies)
        result = { enrichment_filters: false, scanner_overrides: false }

        policies.each do |policy|
          policy.approval_policy.rules.rules.each do |rule|
            result[:enrichment_filters] ||= rule.has_enrichment_filters?
            result[:scanner_overrides] ||= rule.has_scanner_overrides?
            return result if result.values.all?
          end
        end

        result
      end

      def track_policy_event(event, action)
        track_internal_event(
          event,
          project: policy_configuration.project,
          namespace: policy_configuration.namespace,
          additional_properties: { label: action.to_s }
        )
      end
    end
  end
end
