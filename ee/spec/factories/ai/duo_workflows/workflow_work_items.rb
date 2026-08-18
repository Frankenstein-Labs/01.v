# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workflow_work_item, class: 'Ai::DuoWorkflows::WorkflowWorkItem' do
    workflow factory: :duo_workflows_workflow
    work_item { association(:work_item, project: workflow.project) }
    project { workflow.project }
    link_type { :source }
  end
end
