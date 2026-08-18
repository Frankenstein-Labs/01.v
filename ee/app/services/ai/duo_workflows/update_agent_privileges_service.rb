# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class UpdateAgentPrivilegesService
      include Concerns::GovernanceResolution

      def initialize(workflow:, current_user:, agent_privileges: nil, pre_approved_agent_privileges: nil)
        @workflow = workflow
        @agent_privileges = agent_privileges
        @pre_approved_agent_privileges = pre_approved_agent_privileges
        @current_user = current_user
      end

      def execute
        unless @current_user.can?(:update_duo_workflow, @workflow)
          return error_response("Can not update workflow", :unauthorized)
        end

        clamp_error = clamp_privileges_to_governance
        return clamp_error if clamp_error

        update_agent_privileges
      end

      private

      # Local-surface clients (IDE, CLI) cannot be trusted to self-report their
      # privileges: governance is the ceiling. Intersect the requested
      # privileges with the governance resolution for the workflow's surface
      # (most-restrictive-wins), so an admin `deny` always holds. Web surfaces
      # keep their existing trusted behavior because the web UI only submits
      # privileges it resolved from governance itself.
      #
      # Returns an error ServiceResponse when governance cannot be resolved
      # (nothing is persisted, the stored privileges were already clamped), or
      # nil when the update may proceed.
      def clamp_privileges_to_governance
        return unless @agent_privileges || @pre_approved_agent_privileges
        return if web_surface?
        return unless governance_container
        return unless Feature.enabled?(:gitlab_duo_governance_settings, governance_container)
        return unless Feature.enabled?(:duo_workflow_local_tool_governance, governance_container.root_ancestor)

        result = resolve_governance_with_retry(resolution_service, workflow_id: @workflow.id)

        unless result&.success?
          Gitlab::AppLogger.error(
            message: "Governance resolution failed after #{MAX_GOVERNANCE_RETRIES} retries, " \
              "rejecting agent privileges update",
            workflow_id: @workflow.id
          )

          return error_response(
            "Unable to resolve governance rules for this workflow, please retry",
            :governance_resolution_failed
          )
        end

        @agent_privileges &= result.payload[:agent_privileges] if @agent_privileges

        if @pre_approved_agent_privileges
          @pre_approved_agent_privileges &= result.payload[:pre_approved_agent_privileges]
        end

        constrain_pre_approved_privileges

        nil
      end

      # The model validates the pre_approved subset of agent_privileges only
      # on create; re-apply that invariant to the values this update persists,
      # using the stored set for whichever side the request omitted.
      def constrain_pre_approved_privileges
        effective_privileges = @agent_privileges || @workflow.agent_privileges
        effective_pre_approved = @pre_approved_agent_privileges || @workflow.pre_approved_agent_privileges

        @pre_approved_agent_privileges = effective_pre_approved & effective_privileges
      end

      def resolution_service
        # Unrecognized environments (notably `external`) clamp against web rules,
        # matching the surface the JWT-claim mint resolves for them.
        surface = ::Ai::ToolRules::GovernanceSurface.for(
          environment: @workflow.environment,
          container: governance_container
        ) || :web

        ::Ai::ToolRules::ResolutionService.new(
          namespace: governance_container.root_ancestor,
          surface: surface,
          project: @workflow.project
        )
      end

      def web_surface?
        surface = @workflow.environment.presence || :web

        ::Ai::ToolRule::WEB_SURFACES.include?(surface.to_s)
      end

      def governance_container
        @workflow.project || @workflow.namespace
      end

      def update_agent_privileges
        @workflow.agent_privileges = @agent_privileges if @agent_privileges
        @workflow.pre_approved_agent_privileges = @pre_approved_agent_privileges if @pre_approved_agent_privileges

        if @workflow.save
          ServiceResponse.success(
            payload: { workflow: @workflow },
            message: "Agent privileges updated successfully"
          )
        else
          error_response("Failed to update agent privileges: #{@workflow.errors.full_messages.join(', ')}")
        end
      end

      def error_response(message, reason = :bad_request)
        ServiceResponse.error(message: message, reason: reason)
      end
    end
  end
end
