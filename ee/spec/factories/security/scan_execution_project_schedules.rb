# frozen_string_literal: true

FactoryBot.define do
  factory :security_scan_execution_project_schedule, class: 'Security::ScanExecutionProjectSchedule' do
    project
    association :policy_rule_schedule, factory: :security_orchestration_policy_rule_schedule
    association :security_policy, factory: [:security_policy, :scan_execution_policy]

    next_run_at { 1.day.from_now }
    next_run_applied_delay { 0 }
  end
end
