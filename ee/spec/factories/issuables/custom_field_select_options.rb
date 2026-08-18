# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field_select_option, class: 'Issuables::CustomFieldSelectOption' do
    association :custom_field
    namespace { custom_field.namespace }
    sequence(:position)
    value { generate(:short_text) }
  end
end
