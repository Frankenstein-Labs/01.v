# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class WorkflowPolicy < BasePolicy
      condition(:can_use_agentic_chat) do
        can?(:access_duo_agentic_chat, @subject.resource_parent)
      end

      condition(:can_use_duo_workflows_in_container) do
        can?(:duo_workflow, @subject.resource_parent)
      end

      condition(:can_use_duo_workflows_in_project) do
        can?(:duo_workflow, @subject.project)
      end

      condition(:is_workflow_owner) do
        @subject.user == @user ||
          (@user.composite_identity_enforced? && @user.service_account?)
      end

      condition(:can_update_workflow) do
        can?(:update_duo_workflow, @subject)
      end

      condition(:agentic_chat_workflow) do
        @subject.chat?
      end

      condition(:true_duo_workflow) do
        !@subject.chat?
      end

      condition(:duo_workflow_in_ci_available) do
        !!@subject.project&.duo_remote_flows_enabled
      end

      condition(:from_pipeline) do
        @subject.from_pipeline?
      end

      condition(:resumable) do
        # flow registry uses `INPUT_REQUIRED` status to mark the flow as waiting for human input
        @subject.input_required? && workload_pipeline_completed?
      end

      condition(:can_read_agent_artifacts_in_parent) do
        parent = @subject.resource_parent
        next false unless parent

        can?(:read_agent_artifacts, parent)
      end

      # `true_duo_workflow` uses `!chat?`, but `chat?` returns true for ALL
      # foundational agent sessions. This condition explicitly targets non-chat
      # agents so compliance reviewers can access them via the Agent Artifacts dashboard.
      condition(:foundational_agent_workflow) do
        agent = ::Ai::FoundationalChatAgent.with_workflow_definition(@subject.workflow_definition)
        agent.present? && !agent.duo_chat?
      end

      rule { true_duo_workflow & can_use_duo_workflows_in_project & from_pipeline }.policy do
        enable :read_duo_workflow
      end

      rule { true_duo_workflow & can_use_duo_workflows_in_container & is_workflow_owner }.policy do
        enable :read_duo_workflow
        enable :update_duo_workflow
        enable :resume_duo_workflow
      end

      rule { agentic_chat_workflow & can_use_agentic_chat & is_workflow_owner }.policy do
        enable :read_duo_workflow
        enable :update_duo_workflow
      end

      rule { duo_workflow_in_ci_available & can_update_workflow }.policy do
        enable :execute_duo_workflow_in_ci
      end

      rule { ~resumable }.prevent :resume_duo_workflow

      rule { agentic_chat_workflow & is_workflow_owner }.enable :delete_duo_workflow

      # Compliance reviewers with :read_agent_artifacts on the workflow's
      # parent can read agent artifacts for non-chat workflows. :read_duo_workflow
      # is granted so the reviewer can reach the WorkflowType GraphQL node.
      # true_duo_workflow covers software_development and similar workflows.
      # foundational_agent_workflow covers security analyst, orbit, etc.
      # Chat sessions remain private to their owner.
      rule { true_duo_workflow & can_read_agent_artifacts_in_parent }.policy do
        enable :read_duo_workflow
        enable :read_agent_artifacts
      end

      rule { foundational_agent_workflow & can_read_agent_artifacts_in_parent }.policy do
        enable :read_duo_workflow
        enable :read_agent_artifacts
      end

      private

      def workload_pipeline_completed?
        ::Ci::Pipeline.completed_statuses.include?(@subject.last_workload_pipeline_status)
      end
    end
  end
end
