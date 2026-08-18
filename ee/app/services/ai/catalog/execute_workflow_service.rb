# frozen_string_literal: true

module Ai
  module Catalog
    class ExecuteWorkflowService
      include Gitlab::Utils::StrongMemoize

      WORKFLOW_ENVIRONMENT = 'web'
      AGENT_PRIVILEGES = [
        DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
        DuoWorkflows::Workflow::AgentPrivileges::READ_ONLY_GITLAB,
        DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB,
        DuoWorkflows::Workflow::AgentPrivileges::RUN_COMMANDS,
        DuoWorkflows::Workflow::AgentPrivileges::USE_GIT,
        DuoWorkflows::Workflow::AgentPrivileges::RUN_MCP_TOOLS,
        DuoWorkflows::Workflow::AgentPrivileges::START_FLOWS
      ].freeze

      def initialize(current_user, params)
        @current_user = current_user
        @json_config = params[:json_config]
        @container = params[:container]
        @service_account = params[:service_account]
        @flow_definition = params[:flow_definition] || determine_workflow_definition
        @flow_config_id = params[:flow_config_id]
        @flow_config_schema_version_param = params[:flow_config_schema_version]
        @flow_version = params[:flow_version]
        @source_branch = params[:source_branch]
        @additional_context = params[:additional_context]
        @event_type = params[:event_type]
        @triggering_conversation = params[:triggering_conversation]
        @issue_id = params[:issue_id]
        @messaging_callback_context = params[:messaging_callback_context]
        @merge_request_id = params[:merge_request_id]
        @title = params[:title]
        @resume_context = params[:resume_context]
        existing_workflow = @resume_context&.fetch(:existing_workflow, nil)
        @goal = params[:goal] || existing_workflow&.goal
        @item_version = params[:item_version] || existing_workflow&.ai_catalog_item_version
        @item = item_version&.item
      end

      def execute
        return validate unless validate.success?

        workflow = if @resume_context
                     @resume_context[:existing_workflow]
                   else
                     workflow_result = create_workflow
                     return error(workflow_result[:message]) if workflow_result.error?

                     workflow_result.payload[:workflow]
                   end

        start_result = start_workflow_execution(workflow)
        return error(start_result[:message]) if start_result.error?

        ServiceResponse.success(
          payload: {
            workflow: workflow,
            workload_id: start_result.payload[:workload_id],
            flow_config: json_config.to_yaml
          }
        )
      end

      private

      attr_reader :current_user, :json_config, :container, :goal, :item, :item_version, :service_account

      def error(message, payload: {})
        ServiceResponse.error(message: Array(message), payload: payload)
      end

      def validate
        return error('You have insufficient permissions') unless allowed?
        return error('JSON config is required') unless json_config.present? || foundational_flow?
        return error('Goal is required') unless goal.present?

        ServiceResponse.success
      end
      strong_memoize_attr :validate

      def create_workflow
        workflow_params = {
          goal: goal,
          workflow_definition: @flow_definition,
          ai_catalog_item_version_id: item_version&.id,
          environment: WORKFLOW_ENVIRONMENT,
          agent_privileges: AGENT_PRIVILEGES,
          pre_approved_agent_privileges: AGENT_PRIVILEGES,
          service_account: service_account,
          title: @title.presence&.truncate(Ai::DuoWorkflows::Workflow::TITLE_MAX_LENGTH)
        }

        workflow_params[:issue_id] = @issue_id if @issue_id
        workflow_params[:messaging_callback_context] = @messaging_callback_context if @messaging_callback_context
        workflow_params[:merge_request_id] = @merge_request_id if @merge_request_id

        ::Ai::DuoWorkflows::CreateWorkflowService.new(
          container: container,
          current_user: current_user,
          params: workflow_params
        ).execute
      end

      def start_workflow_execution(workflow)
        start_params = build_start_workflow_params(workflow)
        return start_params if start_params.is_a?(ServiceResponse) && start_params.error?

        service_class = if @resume_context
                          ::Ai::DuoWorkflows::ResumeWorkflowService
                        else
                          ::Ai::DuoWorkflows::StartWorkflowService
                        end

        service_class.new(
          workflow: workflow,
          params: start_params
        ).execute
      end

      def build_start_workflow_params(workflow)
        workflow_context_service = workflow_context_generation_service

        oauth_token_result = workflow_context_service.generate_oauth_token_with_composite_identity_support
        return oauth_token_result if oauth_token_result.error?

        workflow_token_result = workflow_context_service.generate_workflow_token
        return workflow_token_result if workflow_token_result.error?

        params = {
          goal: goal,
          flow_config: json_config,
          flow_config_schema_version: flow_config_schema_version,
          workflow_id: workflow.id,
          workflow_oauth_token: oauth_token_result.payload[:oauth_access_token].plaintext_token,
          workflow_service_token: workflow_token_result.payload[:token],
          service_account: service_account,
          source_branch: @source_branch,
          workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user,
            namespace: container&.root_ancestor,
            project: container.is_a?(Project) ? container : nil).to_json,
          duo_agent_platform_feature_setting: workflow_context_service.duo_agent_platform_feature_setting,
          additional_context: @additional_context
        }

        params.merge!(trigger_context_params)
        params.merge!(@resume_context.slice(:human_approval, :human_message)) if @resume_context

        # Callers are responsible for resolving flow params (e.g. via
        # FoundationalFlowStartParamsResolver) before constructing this service.
        # Non-foundational flows have no schema version concept; the fallback
        # to flow_config_schema_version ('v1') covers that case.
        params.merge!(
          flow_definition: @flow_definition,
          flow_config_id: @flow_config_id,
          flow_config_schema_version: @flow_config_schema_version_param || flow_config_schema_version,
          flow_version: @flow_version
        )

        params
      end

      # A foundational flow's `mention` trigger advertises the flow's respond
      # path, whose reply is posted by the messaging adapter
      # (Ai::Messaging::CallbackWorker) when the workflow completes. Without an
      # adapter binding nothing delivers the flow's final answer, so withhold
      # the trigger context and let the flow take its default route (e.g.
      # Security Review runs a full review) instead of producing a reply that
      # is never posted.
      def trigger_context_params
        return {} if foundational_flow? && @event_type.to_s == 'mention' && @messaging_callback_context.blank?

        { event_type: @event_type, triggering_conversation: @triggering_conversation }
      end

      def workflow_context_generation_service
        ::Ai::DuoWorkflows::WorkflowContextGenerationService.new(
          current_user: current_user,
          organization: container.organization,
          container: container,
          service_account: service_account,
          workflow_definition: @flow_definition,
          environment: WORKFLOW_ENVIRONMENT
        )
      end

      def determine_workflow_definition
        'ai_catalog_agent'
      end

      def allowed?
        return false unless Ability.allowed?(current_user, :execute_ai_catalog_item, container)
        return false if item_blocked_by_namespace_restriction?
        return false if outside_restricted_hierarchy?

        true
      end

      def item_blocked_by_namespace_restriction?
        return false if item.nil?

        item.blocked_by_namespace_restriction?(container.root_ancestor)
      end

      def outside_restricted_hierarchy?
        return false unless ::Feature.enabled?(:ai_catalog_internal_visibility, current_user)

        item.present? && item.outside_restricted_hierarchy?(container)
      end

      def flow_config_schema_version
        'v1'
      end

      def foundational_flow?
        ::Ai::Catalog::Item.with_foundational_flow_reference(@flow_definition).present?
      end
      strong_memoize_attr :foundational_flow?
    end
  end
end
