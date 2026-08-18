# frozen_string_literal: true

FactoryBot.define do
  factory :security_policy_requirement,
    class: 'ComplianceManagement::ComplianceFramework::SecurityPolicyRequirement' do
    compliance_requirement factory: :compliance_requirement
    namespace_id { compliance_requirement.framework.namespace_id }
    compliance_framework_security_policy factory: :compliance_framework_security_policy
  end
end
