# frozen_string_literal: true

FactoryBot.define do
  factory :custom_field, class: 'Issuables::CustomField' do
    association :namespace, factory: :group
    field_type { :single_select }
    name { generate(:title) }

    trait :archived do
      archived_at { Time.current }
    end

    trait :number do
      field_type { :number }
    end
  end
end
