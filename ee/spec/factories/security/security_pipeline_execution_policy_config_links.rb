# frozen_string_literal: true

FactoryBot.define do
  factory :security_pipeline_execution_policy_config_link, class: 'Security::PipelineExecutionPolicyConfigLink' do
    project
    security_policy
  end
end
