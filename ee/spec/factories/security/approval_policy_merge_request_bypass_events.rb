# frozen_string_literal: true

FactoryBot.define do
  factory :approval_policy_merge_request_bypass_event, class: 'Security::ApprovalPolicyMergeRequestBypassEvent' do
    project
    security_policy
    merge_request
    user
    reason { 'test' }
  end
end
