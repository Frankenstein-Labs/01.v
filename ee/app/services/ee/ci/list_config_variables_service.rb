# frozen_string_literal: true

module EE
  module Ci
    module ListConfigVariablesService
      extend ::Gitlab::Utils::Override

      private

      override :extract_variables
      def extract_variables(result)
        merge_policy_variables(super)
      end

      override :empty_config_result
      def empty_config_result
        merge_policy_variables(super)
      end

      def merge_policy_variables(config_variables)
        policy_prefill_variables = project.security_policies.type_pipeline_execution_policy
          .each_with_object({}) do |policy, result|
          result.merge!(policy.prefill_variables.transform_values(&:symbolize_keys))
        end

        config_variables.merge(policy_prefill_variables)
      end
    end
  end
end
