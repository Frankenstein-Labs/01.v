# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_system_defined_lifecycle, class: 'WorkItems::Statuses::SystemDefined::Lifecycle' do
    skip_create

    initialize_with do
      WorkItems::Statuses::SystemDefined::Lifecycle.find(attributes[:id] || 1)
    end
  end
end
