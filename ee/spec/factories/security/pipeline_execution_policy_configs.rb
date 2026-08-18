# frozen_string_literal: true

FactoryBot.define do
  factory(
    :pipeline_execution_policy_config,
    class: '::Security::PipelineExecutionPolicy::Config'
  ) do
    policy_index { 0 }

    transient do
      apply_on_empty_pipeline { nil }
    end

    policy do |evaluator|
      base_policy = association(:pipeline_execution_policy)
      if evaluator.apply_on_empty_pipeline
        strategy = base_policy[:pipeline_config_strategy]
        strategy_type = strategy.is_a?(Hash) ? strategy[:type] : strategy
        base_policy[:pipeline_config_strategy] = {
          type: strategy_type,
          apply_on_empty_pipeline: evaluator.apply_on_empty_pipeline.to_s
        }
      end

      base_policy
    end

    policy_config do |evaluator|
      config = association(:security_orchestration_policy_configuration, security_policy_management_project_id: 123456)
      if evaluator.apply_on_empty_pipeline
        config.experiments = { 'apply_on_empty_pipeline_option' => { 'enabled' => true } }
      end

      config
    end

    skip_create
    initialize_with do
      policy = attributes[:policy]
      policy[:content] = attributes[:content] if attributes[:content].present?
      policy_config = attributes[:policy_config]

      allow(policy_config).to receive(:configuration_sha).and_return(attributes[:policy_sha] || 'policy_sha')
      new(policy: policy, policy_config: policy_config, policy_index: attributes[:policy_index])
    end

    trait :override_project_ci do
      policy factory: [:pipeline_execution_policy, :override_project_ci]
    end

    trait :inject_policy do
      policy factory: [:pipeline_execution_policy, :inject_policy]
    end

    trait :suffix_on_conflict do
      policy factory: [:pipeline_execution_policy, :suffix_on_conflict]
    end

    trait :suffix_never do
      policy factory: [:pipeline_execution_policy, :suffix_never]
    end

    trait :skip_ci_allowed do
      policy factory: [:pipeline_execution_policy, :skip_ci_allowed]
    end

    trait :skip_ci_disallowed do
      policy factory: [:pipeline_execution_policy, :skip_ci_disallowed]
    end

    trait :no_pipeline_allowed do
      policy factory: [:pipeline_execution_policy, :no_pipeline_allowed]
    end

    trait :no_pipeline_disallowed do
      policy factory: [:pipeline_execution_policy, :no_pipeline_disallowed]
    end

    trait :variables_override_disallowed do
      policy factory: [:pipeline_execution_policy, :variables_override_disallowed]
    end

    trait :apply_on_empty_pipeline_always do
      policy factory: [:pipeline_execution_policy, :apply_on_empty_pipeline_always]
      policy_config factory: [:security_orchestration_policy_configuration, :with_apply_on_empty_pipeline_experiment]
    end

    trait :apply_on_empty_pipeline_if_no_config do
      policy factory: [:pipeline_execution_policy, :apply_on_empty_pipeline_if_no_config]
      policy_config factory: [:security_orchestration_policy_configuration, :with_apply_on_empty_pipeline_experiment]
    end

    trait :apply_on_empty_pipeline_never do
      policy factory: [:pipeline_execution_policy, :apply_on_empty_pipeline_never]
      policy_config factory: [:security_orchestration_policy_configuration, :with_apply_on_empty_pipeline_experiment]
    end

    trait :scheduled do
      transient do
        scheduled_policy_name { 'Scheduled PEP' }
        scheduled_variables_override { nil }
      end

      policy { nil } # Override default policy association

      initialize_with do
        policy_hash = { name: scheduled_policy_name }
        policy_hash[:variables_override] = scheduled_variables_override if scheduled_variables_override

        policy_config_obj = attributes[:policy_config]
        allow(policy_config_obj).to receive(:configuration_sha).and_return(attributes[:policy_sha] || 'policy_sha')

        new(
          policy: policy_hash.with_indifferent_access,
          policy_config: policy_config_obj,
          policy_index: attributes[:policy_index]
        )
      end
    end
  end
end
