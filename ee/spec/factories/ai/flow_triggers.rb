# frozen_string_literal: true

FactoryBot.define do
  factory :ai_flow_trigger, class: '::Ai::FlowTrigger' do
    project
    user factory: :service_account
    event_types { [::Ai::FlowTrigger::EVENT_TYPES[:mention]] }
    sequence(:description) { |n| "description #{n}" }
    sequence(:config_path) { |n| "path/#{n}.yml" }
    filter { {} }

    trait :for_catalog_consumer do
      project { association(:project, :in_group) }
      config_path { nil }
      user { nil }
      ai_catalog_item_consumer { association(:ai_catalog_item_consumer, :child_item_consumer, project:) }
    end
  end
end
