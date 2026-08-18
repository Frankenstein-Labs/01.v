# frozen_string_literal: true

FactoryBot.define do
  factory :merge_requests_approval_rules_approver_user, class: 'MergeRequests::ApprovalRulesApproverUser' do
    association :approval_rule, factory: :merge_requests_approval_rule
    association :user, factory: :user
  end
end
