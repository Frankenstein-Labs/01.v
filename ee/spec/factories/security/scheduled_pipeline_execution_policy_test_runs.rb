# frozen_string_literal: true

FactoryBot.define do
  factory :security_pipeline_execution_policy_test_run, class: 'Security::ScheduledPipelineExecutionPolicyTestRun' do
    project
    association :security_policy, :pipeline_execution_schedule_policy
    association :pipeline, factory: :ci_pipeline

    state { :running }
  end
end
