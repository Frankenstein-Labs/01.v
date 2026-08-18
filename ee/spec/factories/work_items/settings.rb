# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_settings, class: 'WorkItems::Settings' do
    association :namespace
    organization { nil }
    customizable_type_visibility { false }

    trait :for_organization do
      namespace { nil }
      association :organization
    end
  end
end
