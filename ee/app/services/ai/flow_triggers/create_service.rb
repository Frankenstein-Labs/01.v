# frozen_string_literal: true

module Ai
  module FlowTriggers
    class CreateService < BaseService
      def initialize(project:, current_user:)
        @project = project
        @current_user = current_user
      end

      def execute(params)
        return disallow_new_external_agent_error unless allow_external_agent_trigger?(params)

        result = super do |params|
          project.ai_flow_triggers.create(params)
        end

        audit_flow_trigger('flow_trigger_created', result.payload) if result.success?
        result
      end

      def allow_external_agent_trigger?(params)
        return true if new_external_agents_allowed?

        params[:config_path].blank?
      end
    end
  end
end
