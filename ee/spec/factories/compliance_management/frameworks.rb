# frozen_string_literal: true

FactoryBot.define do
  factory :compliance_framework, class: 'ComplianceManagement::Framework' do
    association :namespace, factory: :group

    name { 'GDPR' }
    description { 'The General Data Protection Regulation (GDPR) is a regulation in EU law on data protection and privacy in the European Union (EU) and the European Economic Area (EEA).' }
    color { '#004494' }

    trait :sox do
      name { 'SOX' }
    end

    trait :with_pipeline do
      pipeline_configuration_full_path { 'compliance.gitlab-ci.yml@test-project' }
    end

    trait :without_pipeline do
      pipeline_configuration_full_path { nil }
    end

    # Helpers for multiple frameworks / different names in a 'order'
    trait :first do
      name { 'First Framework' }
    end
    trait :second do
      name { 'Second Framework' }
    end
    trait :third do
      name { 'Third Framework' }
    end
  end
end
