# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflow_session_artifact, class: 'Ai::DuoWorkflows::SessionArtifact' do
    workflow factory: :duo_workflows_workflow
    user { workflow.user }
    project { workflow.project }
    namespace { workflow.namespace || workflow.project&.project_namespace }
    status { workflow.status_before_type_cast }
    workflow_definition { workflow.workflow_definition }
    workflow_created_at { workflow.created_at || Time.current }
    workflow_updated_at { workflow.updated_at || Time.current }

    trait :with_namespace do
      project { nil }
      workflow factory: [:duo_workflows_workflow, :agentic_chat]
      namespace { association(:group) }
    end
  end
end
