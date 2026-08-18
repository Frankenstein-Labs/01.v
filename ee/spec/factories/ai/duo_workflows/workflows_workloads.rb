# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workload, class: 'Ai::DuoWorkflows::WorkflowsWorkload' do
    project { workflow.project }
    workload factory: :ci_workload
    workflow factory: :duo_workflows_workflow
  end
end
