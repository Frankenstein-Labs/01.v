# frozen_string_literal: true

FactoryBot.define do
  factory(
    :scan_execution_policy_policy_config,
    class: '::Security::ScanExecutionPolicy::Config'
  ) do
    policy factory: :scan_execution_policy

    skip_create
    initialize_with do
      policy = attributes[:policy]
      new(policy: policy)
    end

    trait :skip_ci_disallowed do
      policy factory: [:scan_execution_policy, :skip_ci_disallowed]
    end

    trait :no_pipeline_disallowed do
      policy factory: [:scan_execution_policy, :no_pipeline_disallowed]
    end
  end
end
