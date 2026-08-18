# frozen_string_literal: true

FactoryBot.define do
  factory :scan_execution_policy_rule, class: 'Security::ScanExecutionPolicyRule' do
    security_policy
    sequence(:rule_index)
    security_policy_management_project_id do
      security_policy.security_orchestration_policy_configuration.security_policy_management_project_id
    end
    pipeline

    trait :pipeline do
      type { Security::ScanExecutionPolicyRule.types[:pipeline] }
      content do
        {
          type: 'pipeline',
          branches: []
        }
      end
    end

    trait :schedule do
      type { Security::ScanExecutionPolicyRule.types[:schedule] }
      content do
        {
          type: 'schedule',
          branches: [],
          cadence: "0 * * * *"
        }
      end
    end
  end
end
