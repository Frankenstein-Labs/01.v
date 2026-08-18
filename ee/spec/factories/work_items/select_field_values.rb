# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_select_field_value, class: 'WorkItems::SelectFieldValue' do
    association :work_item
    namespace { work_item&.namespace }
    association :custom_field, field_type: :single_select
    association :custom_field_select_option
  end
end
