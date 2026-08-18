# frozen_string_literal: true

require_relative '../../../../spec/support/helpers/ci/job_factory_helpers'

FactoryBot.define do
  factory(
    :pipeline_execution_policy_pipeline,
    class: '::Security::PipelineExecutionPolicy::Pipeline'
  ) do
    pipeline factory: :ci_empty_pipeline

    trait :no_pipeline_allowed do
      policy_config factory: [:pipeline_execution_policy_config, :no_pipeline_allowed]
    end

    trait :no_pipeline_disallowed do
      policy_config factory: [:pipeline_execution_policy_config, :no_pipeline_disallowed]
    end

    transient do
      job_script { nil }
      apply_on_empty_pipeline { nil }
    end

    policy_config do |evaluator|
      if evaluator.apply_on_empty_pipeline
        association(:pipeline_execution_policy_config, apply_on_empty_pipeline: evaluator.apply_on_empty_pipeline)
      else
        association(:pipeline_execution_policy_config)
      end
    end

    skip_create
    initialize_with do
      new(**attributes.except(:apply_on_empty_pipeline))
    end

    trait :override_project_ci do
      policy_config do |evaluator|
        association(:pipeline_execution_policy_config, :override_project_ci,
          apply_on_empty_pipeline: evaluator.apply_on_empty_pipeline)
      end
    end

    trait :suffix_never do
      policy_config do |evaluator|
        association(:pipeline_execution_policy_config, :suffix_never,
          apply_on_empty_pipeline: evaluator.apply_on_empty_pipeline)
      end
    end

    trait :skip_ci_allowed do
      policy_config do |evaluator|
        association(:pipeline_execution_policy_config, :skip_ci_allowed,
          apply_on_empty_pipeline: evaluator.apply_on_empty_pipeline)
      end
    end

    trait :skip_ci_disallowed do
      policy_config do |evaluator|
        association(:pipeline_execution_policy_config, :skip_ci_disallowed,
          apply_on_empty_pipeline: evaluator.apply_on_empty_pipeline)
      end
    end

    trait :apply_on_empty_pipeline_always do
      apply_on_empty_pipeline { 'always' }
    end

    trait :apply_on_empty_pipeline_if_no_config do
      apply_on_empty_pipeline { 'if_no_config' }
    end

    trait :apply_on_empty_pipeline_never do
      apply_on_empty_pipeline { 'never' }
    end

    after(:build) do |instance, evaluator|
      next unless evaluator.job_script

      job = instance.pipeline.stages[0].statuses[0]
      updated_options = { script: evaluator.job_script }

      Ci::JobFactoryHelpers.mutate_temp_job_definition(job, options: updated_options)
    end
  end
end
