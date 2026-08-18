# frozen_string_literal: true

FactoryBot.define do
  factory :merge_requests_approval_rules_merge_request, class: 'MergeRequests::ApprovalRulesMergeRequest' do
    association :approval_rule, factory: :merge_requests_approval_rule
    association :merge_request, factory: :merge_request
  end
end
