# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class EnablementCheckService
      def initialize(project:, current_user:)
        @project = project
        @current_user = current_user
      end

      def execute
        return unless Ability.allowed?(@current_user, :read_project, @project)

        enabled = Ai::DuoWorkflow.duo_agent_platform_available_for_project?(@project)
        create_duo_workflow_for_ci_allowed = Ability.allowed?(@current_user, :create_duo_workflow_for_ci, @project)
        checks = [
          {
            name: :feature_flag,
            value: true,
            message: _("duo_workflow feature flag must be enabled.")
          },
          {
            name: :duo_features_enabled,
            value: @project.duo_features_enabled,
            message: _("Project must have GitLab Duo features enabled.")
          }, {
            name: :developer_access,
            value: Ability.allowed?(@current_user, :duo_workflow, @project),
            message: _("User must have permission to use Duo Workflows in the project.")
          }, {
            name: :feature_available,
            value: ::Gitlab::Llm::StageCheck.available?(@project,
              :duo_workflow) && @current_user&.allowed_to_use?(:duo_agent_platform),
            message: _("duo_workflow licensed feature must be available for the project and experimental " \
              "features must be enabled.")
          }
        ]

        {
          enabled: enabled,
          create_duo_workflow_for_ci_allowed: create_duo_workflow_for_ci_allowed,
          checks: checks,
          remote_flows_enabled: @project.duo_remote_flows_enabled,
          foundational_flows_enabled: @project.duo_foundational_flows_enabled,
          enabled_foundational_flows: @project.enabled_foundational_flow_references
        }
      end
    end
  end
end
