# frozen_string_literal: true

FactoryBot.define do
  factory :merge_requests_approval_rules_group, class: 'MergeRequests::ApprovalRulesGroup' do
    association :approval_rule, factory: :merge_requests_approval_rule
    association :group, factory: :group
  end
end
