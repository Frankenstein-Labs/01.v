# frozen_string_literal: true

module Resolvers
  module Members
    class ApprovalPolicyResolver < BaseResolver
      include ResolvesOrchestrationPolicy
      include ConstructApprovalPolicies

      type Types::SecurityOrchestration::ApprovalPolicyType, null: true

      def resolve
        policies = object.dependent_security_policies.map do |policy|
          config = policy.security_orchestration_policy_configuration

          policy.to_policy_hash.merge({
            config: config,
            project: config.project,
            namespace: config.namespace,
            inherited: false
          })
        end
        construct_scan_result_policies(policies)
      end

      def container
        object.namespace
      end
    end
  end
end
