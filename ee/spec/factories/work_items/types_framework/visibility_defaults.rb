# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_type_visibility_default, class: 'WorkItems::TypesFramework::VisibilityDefault' do
    association :namespace
    organization { nil }
    work_item_type_id { build(:work_item_system_defined_type, :issue).id }
    enabled { true }

    trait :for_organization do
      association :organization, factory: :organization
      namespace { nil }
    end
  end
end
