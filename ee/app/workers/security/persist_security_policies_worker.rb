# frozen_string_literal: true

module Security
  class PersistSecurityPoliciesWorker
    include ApplicationWorker
    include ::Gitlab::InternalEventsTracking

    data_consistency :sticky
    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once
    feature_category :security_policy_management

    def perform(configuration_id, params = {})
      configuration = Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id) || return

      configuration.invalidate_policy_yaml_cache

      force_resync = params['force_resync'] || false

      persist_policy(configuration, configuration.scan_result_policies, :approval_policy, force_resync)
      persist_policy(configuration, configuration.scan_execution_policy, :scan_execution_policy, force_resync)
      persist_policy(configuration, configuration.pipeline_execution_policy, :pipeline_execution_policy, force_resync)
      persist_policy(configuration, configuration.vulnerability_management_policy, :vulnerability_management_policy,
        force_resync)
      persist_policy(
        configuration,
        configuration.pipeline_execution_schedule_policy,
        :pipeline_execution_schedule_policy,
        force_resync
      )

      if ::Security::DependencyFirewall::Availability.feature_flag_enabled?(configuration.source)
        persist_policy(configuration, configuration.dependency_firewall_policy,
          :dependency_firewall_policy, force_resync)
      end

      track_csp_usage(configuration)

      Security::CollectPoliciesLimitAuditEventsWorker.perform_async(configuration.id)
    end

    private

    def persist_policy(configuration, policies, policy_type, force_resync = false)
      Security::SecurityOrchestrationPolicies::PersistPolicyService.new(
        policy_configuration: configuration,
        policies: policies,
        policy_type: policy_type,
        force_resync: force_resync
      ).execute
    end

    def track_csp_usage(configuration)
      return unless configuration.designated_as_csp?

      track_internal_event(
        'sync_csp_configuration',
        namespace: configuration.namespace
      )
    end
  end
end
