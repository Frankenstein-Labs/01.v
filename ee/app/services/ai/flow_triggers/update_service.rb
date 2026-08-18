# frozen_string_literal: true

module Ai
  module FlowTriggers
    class UpdateService < BaseService
      def initialize(project:, current_user:, trigger:)
        @project = project
        @current_user = current_user
        @trigger = trigger
      end

      def execute(params)
        return disallow_new_external_agent_error if disallow_config_path_change?(params)

        result = super do |params|
          @trigger.update(params)
          @trigger
        end

        audit_flow_trigger('flow_trigger_updated', result.payload) if result.success?
        result
      end

      private

      # Prevent an AI Catalog trigger from becoming a "manual" External Agent trigger
      # unless the user is allowed to create new External Agents.
      # See https://gitlab.com/gitlab-org/gitlab/-/issues/583687.
      def disallow_config_path_change?(params)
        @trigger.ai_catalog_item_consumer_id.present? && params[:config_path].present? && !new_external_agents_allowed?
      end
    end
  end
end
