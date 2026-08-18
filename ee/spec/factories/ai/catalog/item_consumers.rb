# frozen_string_literal: true

FactoryBot.define do
  factory :ai_catalog_item_consumer, class: 'Ai::Catalog::ItemConsumer' do
    for_agent
    enabled { true }
    locked { true }
    project { association :project, :in_group if group.nil? && organization.nil? }
    service_account do
      if project.nil? && group&.root? && (item.flow? || item.third_party_flow?)
        association(:service_account, provisioned_by_group: group)
      end
    end

    trait :for_agent do
      item { association(:ai_catalog_agent, organization:) }
    end

    trait :for_flow do
      item { association(:ai_catalog_flow, organization:) }
    end

    trait :for_third_party_flow do
      item { association(:ai_catalog_third_party_flow, organization:) }
    end

    trait :child_item_consumer do
      for_flow

      parent_item_consumer do
        association(:ai_catalog_item_consumer, :parent_item_consumer, group: project.root_ancestor, item: item)
      end
    end

    trait :parent_item_consumer do
      for_flow

      group { association :group }

      service_account { association(:service_account, provisioned_by_group: group) }
    end

    trait :with_triggers do
      transient do
        event_types { [] }
      end

      after(:create) do |item_consumer, evaluator|
        # rubocop:disable RSpec/FactoryBot/StrategyInCallback -- requires parent record
        if item_consumer.parent_item_consumer && evaluator.event_types.any?
          create(
            :ai_flow_trigger,
            :for_catalog_consumer,
            ai_catalog_item_consumer: item_consumer,
            project: item_consumer.project,
            event_types: evaluator.event_types
          )
        end
        # rubocop:enable RSpec/FactoryBot/StrategyInCallback
      end
    end
  end
end
