# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_text_field_value, class: 'WorkItems::TextFieldValue' do
    association :work_item
    namespace { work_item&.namespace }
    association :custom_field, field_type: :text
    value { generate(:short_text) }
  end
end
