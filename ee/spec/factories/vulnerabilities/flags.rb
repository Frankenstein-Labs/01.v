# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerabilities_flag, class: 'Vulnerabilities::Flag' do
    finding factory: :vulnerabilities_finding
    origin { 'post analyzer X' }
    description { 'static string to sink' }
    confidence_score { 0.8 }
    status { :not_started }

    trait :false_positive do
      flag_type { Vulnerabilities::Flag.flag_types[:false_positive] }
    end

    trait :with_workflow do
      workflow { association(:duo_workflows_workflow) }
    end
  end
end
