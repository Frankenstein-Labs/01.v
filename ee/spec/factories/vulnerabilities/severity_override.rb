# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_severity_override, class: 'Vulnerabilities::SeverityOverride' do
    vulnerability
    project_id { vulnerability.project.id }
    author factory: :user
    original_severity { :low }
    new_severity { :critical }
  end
end
