# frozen_string_literal: true

module Security
  class SyncScanPoliciesWorker
    include ApplicationWorker

    data_consistency :always

    deduplicate :until_executed, if_deduplicated: :reschedule_once
    idempotent!

    feature_category :security_policy_management

    def perform(configuration_id, params = {})
      configuration = Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id)

      return unless configuration

      Security::SecurityOrchestrationPolicies::SyncPoliciesService
        .new(configuration: configuration, params: params.symbolize_keys)
        .execute
    end
  end
end
