# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_foundational_flow, class: 'Ai::Catalog::FoundationalFlow' do
    skip_create
    code_review

    initialize_with do
      Ai::Catalog::FoundationalFlow[attributes[:foundational_flow_reference]]
    end

    trait :code_review do
      foundational_flow_reference { 'code_review/v1' }
    end

    trait :fix_pipeline do
      foundational_flow_reference { 'fix_pipeline/v1' }
    end

    trait :sast_fp_detection do
      foundational_flow_reference { 'sast_fp_detection/v1' }
    end

    trait :resolve_sast_vulnerability do
      foundational_flow_reference { 'resolve_sast_vulnerability/v1' }
    end

    trait :developer do
      foundational_flow_reference { 'developer/v1' }
    end

    trait :convert_to_gl_ci do
      foundational_flow_reference { 'convert_to_gl_ci/v1' }
    end

    trait :recommend_reviewers do
      foundational_flow_reference { 'recommend_reviewers/v1' }
    end

    trait :secrets_fp_detection do
      foundational_flow_reference { 'secrets_fp_detection/v1' }
    end

    trait :resolve_dependency_bump do
      foundational_flow_reference { 'resolve_dependency_bump/experimental' }
    end

    trait :security_review do
      foundational_flow_reference { 'security_review/v1' }
    end

    trait :with_item do
      after(:build) do |flow|
        next if Ai::Catalog::Item.with_foundational_flow_reference(flow.foundational_flow_reference).exists?

        # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- not your regular association
        create(
          :ai_catalog_flow,
          :public,
          :with_released_version,
          foundational_flow_reference: flow.foundational_flow_reference
        )
        # rubocop:enable RSpec/FactoryBot/StrategyInCallback
      end
    end
  end
end
