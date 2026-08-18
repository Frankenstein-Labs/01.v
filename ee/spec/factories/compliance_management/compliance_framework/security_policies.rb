# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_framework_security_policy, class: 'ComplianceManagement::ComplianceFramework::SecurityPolicy' do
    framework { association :compliance_framework }
    policy_configuration { association :security_orchestration_policy_configuration }
    policy_index { 0 }
  end
end
