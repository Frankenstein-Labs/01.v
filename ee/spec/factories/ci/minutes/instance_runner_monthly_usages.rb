# frozen_string_literal: true

FactoryBot.define do
  factory :ci_instance_runner_monthly_usage, class: 'Ci::Minutes::InstanceRunnerMonthlyUsage' do
    project
    association :runner, factory: :ci_runner
    association :root_namespace, factory: :namespace
    billing_month { Date.current.beginning_of_month }
    compute_minutes_used { 100.0 }
    runner_duration_seconds { 3600 }
  end
end
