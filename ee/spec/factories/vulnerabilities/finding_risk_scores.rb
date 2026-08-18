# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_finding_risk_score, class: 'Vulnerabilities::FindingRiskScore' do
    finding factory: :vulnerabilities_finding
    project { finding.project }
    risk_score { Vulnerabilities::RiskScore.from_finding(finding).score }
  end
end
