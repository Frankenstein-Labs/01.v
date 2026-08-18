# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item, class: 'Ai::Catalog::Item' do
    agent
    sequence(:name) { |n| "Item #{n}" }
    sequence(:description) { |n| "Item #{n}" }

    factory :ai_catalog_agent, traits: [:agent]
    factory :ai_catalog_flow, traits: [:flow]
    factory :ai_catalog_third_party_flow, traits: [:third_party_flow]

    trait :agent do
      item_type { 'agent' }
    end

    trait :flow do
      item_type { 'flow' }
    end

    trait :third_party_flow do
      item_type { 'third_party_flow' }
    end

    trait :public do
      visibility { :public }
    end

    trait :private do
      visibility { :private }
    end

    trait :restricted do
      visibility { :restricted }
    end

    trait :soft_deleted do
      deleted_at { Time.current }
    end

    trait :with_foundational_flow_reference do
      flow
      public # rubocop:disable Layout/EmptyLinesAroundAccessModifier -- false positive, this is a FactoryBot trait
      foundational_flow_reference { "fix_pipeline/v1" }
    end

    trait :with_released_version do
      after(:create) do |item, _|
        create("ai_catalog_#{item.item_type}_version", :released, item: item)
      end
    end

    versions do |item|
      version_factory = "ai_catalog_#{item.item_type}_version"
      build_list(version_factory, 1, item: nil)
    end

    after(:build) do |item, _|
      item.latest_version ||= item.versions.first

      item.organization ||=
        item.project&.organization ||
        build(:common_organization) # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- unable to create with association()
    end
  end
end
