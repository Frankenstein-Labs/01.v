# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workflow_pipeline, class: 'Ai::DuoWorkflows::WorkflowPipeline' do
    workflow factory: :duo_workflows_workflow
    pipeline { association(:ci_pipeline, project: workflow.project) }
    project { workflow.project }
    link_type { :source }
  end
end
