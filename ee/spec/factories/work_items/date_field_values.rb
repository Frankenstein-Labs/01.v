# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_date_field_value, class: 'WorkItems::DateFieldValue' do
    association :work_item
    namespace { work_item&.namespace }
    association :custom_field, field_type: :date
    value { generate(:sequential_date) }
  end
end
