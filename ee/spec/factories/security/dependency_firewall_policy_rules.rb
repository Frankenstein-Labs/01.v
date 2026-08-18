# frozen_string_literal: true

FactoryBot.define do
  factory :dependency_firewall_policy_rule, class: 'Security::DependencyFirewallPolicyRule' do
    security_policy { association(:security_policy, :dependency_firewall_policy) }
    sequence(:rule_index)
    security_policy_management_project_id do
      security_policy.security_orchestration_policy_configuration.security_policy_management_project_id
    end
    type { Security::DependencyFirewallPolicyRule.types[:license] }
    content do
      {
        denied: [{ name: 'MIT License' }]
      }
    end
  end
end
