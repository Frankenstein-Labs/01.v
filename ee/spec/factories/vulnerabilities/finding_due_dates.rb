# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_finding_due_date, class: 'Vulnerabilities::FindingDueDate' do
    association :finding, factory: :vulnerabilities_finding

    project { finding.project }

    due_date { 7.days.from_now.to_date }
  end
end
