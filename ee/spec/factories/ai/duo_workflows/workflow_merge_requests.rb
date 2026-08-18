# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workflow_merge_request, class: 'Ai::DuoWorkflows::WorkflowMergeRequest' do
    workflow factory: :duo_workflows_workflow
    merge_request { association(:merge_request, source_project: workflow.project) }
    project { workflow.project }
    link_type { :source }
  end
end
