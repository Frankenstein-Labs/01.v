# frozen_string_literal: true

FactoryBot.define do
  factory :work_item_type_visibility, class: 'WorkItems::TypesFramework::Visibility' do
    association :namespace
    work_item_type_id { build(:work_item_system_defined_type, :issue).id }
    enabled { true }
    propagate { false }
  end
end
