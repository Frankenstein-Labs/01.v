# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class UpdatePipelineExecutionPolicyMetadataService
      def initialize(security_policy:, enforced_scans:, prefill_variables:)
        @security_policy = security_policy
        @enforced_scans = enforced_scans
        @prefill_variables = prefill_variables
      end

      def execute
        return ServiceResponse.success(payload: security_policy) unless security_policy.type_pipeline_execution_policy?

        security_policy.enforced_scans = enforced_scans
        security_policy.prefill_variables = prefill_variables
        security_policy.save!
        ServiceResponse.success(payload: security_policy)
      rescue StandardError => e
        ServiceResponse.error(message: e.message)
      end

      private

      attr_accessor :security_policy, :enforced_scans, :prefill_variables
    end
  end
end
