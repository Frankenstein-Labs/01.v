# frozen_string_literal: true

FactoryBot.define do
  factory :merge_requests_approval_rule, class: 'MergeRequests::ApprovalRule' do
    sequence(:name) { |n| "Approval Rule #{n}" }
    approvals_required { 2 }
    rule_type { :regular }
    origin { :merge_request }

    transient do
      group { nil }
      sharding_project { nil }
    end

    after(:build) do |rule, evaluator|
      if evaluator.group
        rule.group_id = evaluator.group.id
        rule.project_id = nil
      elsif evaluator.sharding_project
        rule.project_id = evaluator.sharding_project.id
        rule.group_id = nil
      elsif rule.group_id.present?
        # group_id explicitly set, clear project_id
        rule.project_id = nil
      elsif rule.project_id.present?
        # project_id explicitly set, clear group_id
        rule.group_id = nil
      end
    end

    trait :with_users do
      transient do
        user { association(:user) }
      end

      after(:create) do |rule, evaluator|
        rule.approval_rules_approver_users.create!(user: evaluator.user)
      end
    end

    trait :with_groups do
      transient do
        approver_group { association(:group) }
      end

      after(:create) do |rule, evaluator|
        rule.approval_rules_approver_groups.create!(group: evaluator.approver_group)
      end
    end

    trait :from_group do
      origin { :group }
    end

    trait :from_project do
      origin { :project }
    end

    trait :from_merge_request do
      origin { :merge_request }
    end

    trait :with_source_rule do
      association :source_rule, factory: :merge_requests_approval_rule
    end
  end
end
