# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workflow_note, class: 'Ai::DuoWorkflows::WorkflowNote' do
    workflow factory: :duo_workflows_workflow
    note { association(:note, project: workflow.project) }
    project { workflow.project }
    link_type { :created }
  end
end
