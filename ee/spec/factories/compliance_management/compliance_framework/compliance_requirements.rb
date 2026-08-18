# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_requirement, class: 'ComplianceManagement::ComplianceFramework::ComplianceRequirement' do
    association :framework, factory: :compliance_framework
    namespace_id { framework.namespace_id }
    sequence(:name) { |n| "Merge Request Controls#{n}" }
    description { 'Requirement for adding checks related to merge request controls' }
  end
end
