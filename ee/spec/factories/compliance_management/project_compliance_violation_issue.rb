# frozen_string_literal: true

FactoryBot.define do
  factory :project_compliance_violation_issue, class: 'ComplianceManagement::Projects::ComplianceViolationIssue' do
    association :project

    project_compliance_violation do
      association :project_compliance_violation, project: project, namespace: project.namespace
    end

    issue { association :issue, project: project }
  end
end
