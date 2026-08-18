# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_number_field_value, class: 'WorkItems::NumberFieldValue' do
    association :work_item
    namespace { work_item&.namespace }
    association :custom_field, field_type: :number
    value { rand(10000) }
  end
end
