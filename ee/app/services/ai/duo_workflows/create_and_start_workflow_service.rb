# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateAndStartWorkflowService
      include ::Gitlab::Utils::StrongMemoize

      MISSING_WORKFLOW_TOKEN_ERROR = 'Could not obtain Duo Workflow token'
      MISSING_OAUTH_TOKEN_ERROR = 'Could not obtain authentication token'
      MISSING_WORKFLOW_DEFINITION_ERROR = 'Workflow definition cannot be blank'
      MISSING_SOURCE_BRANCH_ERROR = 'Source branch cannot be blank'
      MISSING_SERVICE_ACCOUNT_ERROR = 'Could not resolve the service account for this flow'
      FLOW_NOT_ENABLED_ERROR = 'Workflow not enabled for this project/namespace'

      def initialize(container:, resource:, current_user:, goal:, source_branch:, workflow_definition:)
        @container = container
        @resource = resource
        @current_user = current_user
        @goal = goal
        @source_branch = source_branch
        @workflow_definition = workflow_definition
      end

      def execute
        return validation if validation.error?

        create_result = ::Ai::DuoWorkflows::CreateWorkflowService.new(
          container: container,
          current_user: current_user,
          params: create_workflow_params
        ).execute

        if create_result.error?
          return error(
            create_result.message,
            create_result.payload[:reason] || create_result.reason || :create_workflow
          )
        end

        workflow = create_result[:workflow]

        start_result = ::Ai::DuoWorkflows::StartWorkflowService.new(
          workflow: workflow,
          params: start_workflow_params(workflow)
        ).execute

        if start_result.error?
          return error(
            start_result.message,
            start_result.payload[:reason] || start_result.reason || :start_workflow
          )
        end

        workload_id = start_result.payload[:workload_id]
        message = start_result.message

        ServiceResponse.success(message: message, payload: { workflow: workflow, workload_id: workload_id })
      end

      private

      attr_reader :container, :resource, :current_user, :workflow_definition, :goal, :source_branch

      def validation
        return error(MISSING_WORKFLOW_DEFINITION_ERROR, :invalid_workflow_definition) if workflow_definition.blank?
        return error(MISSING_SOURCE_BRANCH_ERROR, :invalid_source_branch) if source_branch.blank?
        return error(FLOW_NOT_ENABLED_ERROR, :flow_not_enabled) unless flow_configured_for_container?
        return error(MISSING_SERVICE_ACCOUNT_ERROR, :invalid_service_account) if service_account.nil?
        return error(MISSING_WORKFLOW_TOKEN_ERROR, :invalid_duo_workflow_token) if workflow_service_token.nil?
        return error(MISSING_OAUTH_TOKEN_ERROR, :invalid_oauth_token) if workflow_oauth_token.nil?

        ServiceResponse.success
      end
      strong_memoize_attr :validation

      def flow_configured_for_container?
        catalog_item_id = workflow_definition.catalog_item&.id

        return false if catalog_item_id.blank?

        container.duo_foundational_flows_enabled &&
          container.enabled_flow_catalog_item_ids.include?(catalog_item_id)
      end

      def error(message, reason, payload = {})
        ServiceResponse.error(message: message, reason: reason, payload: payload)
      end

      def workflow_context_generation_service
        ::Ai::DuoWorkflows::WorkflowContextGenerationService.new(
          current_user: current_user,
          organization: container.organization,
          container: container,
          workflow_definition: workflow_definition_reference,
          service_account: service_account,
          environment: workflow_definition.environment
        )
      end
      strong_memoize_attr :workflow_context_generation_service

      def create_workflow_params
        {
          goal: goal,
          workflow_definition: workflow_definition_reference,
          agent_privileges: workflow_definition.agent_privileges,
          pre_approved_agent_privileges: workflow_definition.pre_approved_agent_privileges,
          allow_agent_to_request_user: workflow_definition.allow_agent_to_request_user,
          environment: workflow_definition.environment,
          service_account: service_account
        }
      end

      def workflow_definition_reference
        workflow_definition.foundational_flow_reference
      end

      def start_workflow_params(workflow)
        {
          goal: goal,
          workflow_id: workflow.id,
          workflow_oauth_token: workflow_oauth_token,
          workflow_service_token: workflow_service_token,
          service_account: service_account,
          source_branch: source_branch,
          workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user,
            namespace: container&.root_ancestor,
            project: container.is_a?(Project) ? container : nil).to_json,
          duo_agent_platform_feature_setting: workflow_context_generation_service.duo_agent_platform_feature_setting,
          additional_context: workflow_definition.resolve_additional_context_for(resource: resource)
        }.merge(::Ai::DuoWorkflows::FoundationalFlowStartParamsResolver.call(workflow_definition_reference, container,
          user: current_user))
      end

      def workflow_service_token
        workflow_token_result = workflow_context_generation_service.generate_workflow_token
        return if workflow_token_result.error?

        workflow_token_result.payload.fetch(:token)
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e)
        nil
      end
      strong_memoize_attr :workflow_service_token

      def workflow_oauth_token
        oauth_token_result = workflow_context_generation_service.generate_oauth_token_with_composite_identity_support
        return if oauth_token_result.error?

        oauth_token_result.payload.fetch(:oauth_access_token).plaintext_token
      rescue StandardError => e
        ::Gitlab::ErrorTracking.track_exception(e)
        nil
      end
      strong_memoize_attr :workflow_oauth_token

      def service_account
        return unless workflow_definition.catalog_item

        result = ::Ai::Catalog::ItemConsumers::ResolveServiceAccountService.new(
          container: container,
          item: workflow_definition.catalog_item
        ).execute

        return if result.error?

        result.payload.fetch(:service_account)
      end
      strong_memoize_attr :service_account
    end
  end
end
