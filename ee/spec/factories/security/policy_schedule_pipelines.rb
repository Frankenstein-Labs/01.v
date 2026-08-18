# frozen_string_literal: true

FactoryBot.define do
  factory :security_policy_schedule_pipeline, class: 'Security::PolicySchedulePipeline' do
    project
    association :security_policy, :pipeline_execution_schedule_policy
    pipeline { association :ci_pipeline, project: project }
  end
end
