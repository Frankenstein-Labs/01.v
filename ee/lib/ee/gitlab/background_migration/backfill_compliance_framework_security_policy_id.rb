# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillComplianceFrameworkSecurityPolicyId
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_compliance_framework_security_policy_id
          scope_to ->(relation) { relation.where(security_policy_id: nil) }
        end

        class SecurityPolicy < ::ApplicationRecord
          self.table_name = 'security_policies'
          self.inheritance_column = :_type_disabled

          def scope_has_framework?(framework_id)
            scope['compliance_frameworks'].to_a.any? { |framework| framework['id'] == framework_id }
          end
        end

        class ComplianceFrameworkSecurityPolicy < ::ApplicationRecord
          self.table_name = 'compliance_framework_security_policies'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            sub_batch.each do |compliance_framework_security_policy|
              process_compliance_framework_security_policy(compliance_framework_security_policy)
            end
          end
        end

        private

        def process_compliance_framework_security_policy(compliance_framework_security_policy)
          policy_configuration_id = compliance_framework_security_policy.policy_configuration_id
          framework_id = compliance_framework_security_policy.framework_id

          security_policies = SecurityPolicy.where(
            security_orchestration_policy_configuration_id: policy_configuration_id
          )

          matching_policies = security_policies.select { |policy| policy.scope_has_framework?(framework_id) }
          return if matching_policies.empty?

          attrs = matching_policies.map do |policy|
            {
              security_policy_id: policy.id,
              framework_id: framework_id,
              policy_configuration_id: policy_configuration_id,
              policy_index: policy.policy_index
            }
          end

          return unless attrs.any?

          ComplianceFrameworkSecurityPolicy.upsert_all(
            attrs, unique_by: [:security_policy_id, :framework_id]
          )
          ComplianceFrameworkSecurityPolicy.where(
            security_policy_id: nil,
            policy_configuration_id: policy_configuration_id,
            framework_id: framework_id
          ).delete_all
        end
      end
    end
  end
end
