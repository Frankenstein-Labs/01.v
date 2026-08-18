# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_finding_remediation, class: 'Vulnerabilities::FindingRemediation' do
    finding factory: :vulnerabilities_finding
    remediation factory: :vulnerabilities_remediation
  end
end
