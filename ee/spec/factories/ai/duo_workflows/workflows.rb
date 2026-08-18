# frozen_string_literal: true

FactoryBot.define do
  factory :duo_workflows_workflow, class: 'Ai::DuoWorkflows::Workflow' do
    project { association(:project) }
    user { association(:user, developer_of: project) }
    goal { "Fix pipeline" }
    agent_privileges { [Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES] }
    pre_approved_agent_privileges { [] }
    workflow_definition { "software_development" }
    image { "registry.gitlab.com/gitlab-org/duo-workflow/test-image:latest" }
    environment { :ide }

    trait :agentic_chat do
      workflow_definition { "chat" }
    end

    trait :created do
      status { 0 }
    end

    trait :running do
      status { 1 }
    end

    trait :finished do
      status { 3 }
    end

    trait :failed do
      status { 4 }
    end

    trait :input_required do
      status { 6 }
    end

    trait :external do
      environment { :external }
      agent_type { 'claude-code' }
      sync_type { :hook }
    end

    trait :tool_call_approval_required do
      status { 8 }
    end

    after(:build) do |workflow, _|
      workflow.project_id = nil if workflow.namespace_id
    end
  end
end
