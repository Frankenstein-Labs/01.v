# frozen_string_literal: true

FactoryBot.define do
  factory :merge_requests_approval_rules_project, class: 'MergeRequests::ApprovalRulesProject' do
    association :approval_rule, factory: :merge_requests_approval_rule
    association :project, factory: :project
  end
end
