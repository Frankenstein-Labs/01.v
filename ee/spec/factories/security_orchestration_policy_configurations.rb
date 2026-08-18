# frozen_string_literal: true

FactoryBot.define do
  factory :security_orchestration_policy_configuration, class: 'Security::OrchestrationPolicyConfiguration' do
    project
    namespace { nil }
    security_policy_management_project { association(:project) }

    trait :namespace do
      project { nil }
      namespace
    end

    trait :with_apply_on_empty_pipeline_experiment do
      experiments { { apply_on_empty_pipeline_option: { enabled: true } } }
    end
  end
end
