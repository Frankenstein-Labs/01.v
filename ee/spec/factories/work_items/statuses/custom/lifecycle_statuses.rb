# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_custom_lifecycle_status, class: 'WorkItems::Statuses::Custom::LifecycleStatus' do
    association :lifecycle, factory: :work_item_custom_lifecycle
    association :status, factory: :work_item_custom_status
    namespace { lifecycle.namespace }
    sequence(:position) { |n| n }
  end
end
