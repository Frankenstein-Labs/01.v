# frozen_string_literal: true

module Ai
  module Messaging
    # Resolves everything needed to trigger a foundational flow when the caller
    # has no project context. Derives the workspace project, service account,
    # and flow version params from the user's default Duo namespace.
    #
    # Input:  (flow_reference, current_user)
    # Output: { project, service_account, flow_config_id, flow_config_schema_version, flow_version }
    #         or a failure with reason symbol.
    #
    # Used by project-less surfaces (Slack, future Teams, etc.) that need a
    # default project to run a flow.
    class DefaultProjectFlowResolver
      include ::Gitlab::Utils::StrongMemoize

      def initialize(flow_reference:, current_user:)
        @flow_reference = flow_reference
        @current_user = current_user
      end

      def execute
        return error('No default Duo namespace configured', :namespace_not_configured) unless namespace

        unless flow_enabled?
          return error(
            "The #{flow_reference} flow is not enabled for this namespace.",
            :flow_not_enabled
          )
        end

        project_result = resolve_workspace_project
        return error(project_result.message, :workspace_project_error) unless project_result.success?

        service_account = resolve_service_account
        return error('Could not resolve service account', :service_account_error) unless service_account

        project = project_result.payload[:project]
        flow_params = resolve_flow_params(project)

        ServiceResponse.success(payload: {
          project: project,
          service_account: service_account,
          flow_config_id: flow_params[:flow_config_id],
          flow_config_schema_version: flow_params[:flow_config_schema_version],
          flow_version: flow_params[:flow_version]
        })
      end

      private

      attr_reader :flow_reference, :current_user

      def namespace
        current_user.default_duo_namespace&.root_ancestor
      end
      strong_memoize_attr :namespace

      def workflow_definition
        ::Ai::Catalog::FoundationalFlow[flow_reference]
      end
      strong_memoize_attr :workflow_definition

      def flow_enabled?
        catalog_item = workflow_definition&.catalog_item
        return false unless catalog_item

        namespace.duo_foundational_flows_enabled &&
          namespace.enabled_flow_catalog_item_ids.include?(catalog_item.id)
      end

      def resolve_workspace_project
        WorkspaceProjectService.new(
          namespace: namespace, current_user: current_user
        ).execute
      end

      def resolve_service_account
        catalog_item = workflow_definition&.catalog_item
        return unless catalog_item

        result = ::Ai::Catalog::ItemConsumers::ResolveServiceAccountService.new(
          container: namespace,
          item: catalog_item
        ).execute

        return unless result.success?

        result.payload[:service_account]
      end

      # By this point workflow_definition is validated (flow_enabled? passed),
      # so the params resolver is guaranteed to return a complete hash.
      def resolve_flow_params(project)
        resolved = ::Ai::DuoWorkflows::FoundationalFlowStartParamsResolver.call(
          flow_reference, project, user: current_user
        )

        {
          flow_config_id: resolved[:flow_config_id],
          flow_config_schema_version: resolved[:flow_config_schema_version],
          flow_version: resolved[:flow_version]
        }
      end

      def error(message, reason)
        ServiceResponse.error(message: message, reason: reason)
      end
    end
  end
end
