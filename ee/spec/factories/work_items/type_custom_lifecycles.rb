# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_type_custom_lifecycle, class: 'WorkItems::TypeCustomLifecycle' do
    association :work_item_type
    association :lifecycle, factory: :work_item_custom_lifecycle
    namespace { lifecycle.namespace }
  end
end
