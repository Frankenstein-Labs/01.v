# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_type_custom_field, class: 'WorkItems::TypeCustomField' do
    association :work_item_type, :issue, factory: :work_item_system_defined_type
    association :custom_field
    namespace { custom_field.namespace }
  end
end
