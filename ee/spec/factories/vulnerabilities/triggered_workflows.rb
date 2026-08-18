# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_triggered_workflow, class: 'Vulnerabilities::TriggeredWorkflow' do
    vulnerability_occurrence { association(:vulnerabilities_finding) }
    workflow { association(:duo_workflows_workflow) }
    workflow_name { :sast_fp_detection }

    trait :resolve_sast_vulnerability do
      workflow_name { :resolve_sast_vulnerability }
    end
  end
end
