# frozen_string_literal: true

FactoryBot.define do
  factory :scan_result_policy_read, class: 'Security::ScanResultPolicyRead' do
    security_orchestration_policy_configuration
    project

    orchestration_policy_idx { 0 }
    match_on_inclusion_license { true }
    sequence :rule_idx
    custom_roles { [] }

    trait :prevent_pushing_and_force_pushing do
      project_approval_settings { { prevent_pushing_and_force_pushing: true } }
    end

    trait :blocking_protected_branches do
      project_approval_settings { { block_branch_modification: true } }
    end

    trait :prevent_approval_by_author do
      project_approval_settings { { prevent_approval_by_author: true } }
    end

    trait :prevent_approval_by_commit_author do
      project_approval_settings { { prevent_approval_by_commit_author: true } }
    end

    trait :require_password_to_approve do
      project_approval_settings { { require_password_to_approve: true } }
    end

    trait :remove_approvals_with_new_commit do
      project_approval_settings { { remove_approvals_with_new_commit: true } }
    end

    trait :with_send_bot_message do
      transient do
        bot_message_enabled { true }
      end

      send_bot_message { { enabled: bot_message_enabled } }
    end

    trait :fail_open do
      fallback_behavior { { fail: "open" } }
    end

    trait :fail_closed do
      fallback_behavior { { fail: "closed" } }
    end

    trait :targeting_commits do
      commits { :any }
    end

    trait :with_approval_policy_rule do
      approval_policy_rule do
        association(:approval_policy_rule, :scan_finding,
          security_policy: association(:security_policy, :approval_policy,
            security_orchestration_policy_configuration: security_orchestration_policy_configuration,
            policy_index: orchestration_policy_idx))
      end
    end
  end
end
