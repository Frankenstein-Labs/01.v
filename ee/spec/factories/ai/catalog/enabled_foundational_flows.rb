# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_enabled_foundational_flow, class: 'Ai::Catalog::EnabledFoundationalFlow' do
    catalog_item { association :ai_catalog_item, :with_foundational_flow_reference }

    trait :for_namespace do
      namespace { association :group }
      project { nil }
    end

    trait :for_project do
      namespace { nil }
      project { association :project }
    end

    # Default to namespace context
    for_namespace
  end
end
