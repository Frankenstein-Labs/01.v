# frozen_string_literal: true

FactoryBot.define do
  factory :approval_policy_rule_project_link, class: 'Security::ApprovalPolicyRuleProjectLink' do
    project
    approval_policy_rule
  end
end
