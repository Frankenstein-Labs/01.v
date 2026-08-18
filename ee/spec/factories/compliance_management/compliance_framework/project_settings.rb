# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_framework_project_setting, class: 'ComplianceManagement::ComplianceFramework::ProjectSettings' do
    project
    compliance_management_framework factory: :compliance_framework
    created_at { Time.current }

    trait :sox do
      association :compliance_management_framework, :sox, factory: :compliance_framework
    end

    trait :first_framework do
      association :compliance_management_framework, :first, factory: :compliance_framework
      created_at { 3.days.ago }
    end

    trait :second_framework do
      association :compliance_management_framework, :second, factory: :compliance_framework
      created_at { 2.days.ago }
    end

    trait :third_framework do
      association :compliance_management_framework, :third, factory: :compliance_framework
      created_at { 1.day.ago }
    end
  end
end
