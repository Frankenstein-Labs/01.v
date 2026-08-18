# frozen_string_literal: true

module API
  module Helpers
    module DuoWorkflowHelpers
      include Gitlab::Utils::StrongMemoize

      def push_ai_gateway_headers(scope: nil, subject: current_user)
        governing_namespace = current_user.governing_namespace(scope)

        push_feature_flags(governing_namespace)

        Gitlab::AiGateway.public_headers(
          user: current_user,
          ai_feature_name: :duo_workflow,
          unit_primitive_name: :duo_workflow_execute_workflow,
          organization_id: governing_namespace&.organization_id,
          governing_namespace_id: governing_namespace&.id,
          subject: subject
        ).each do |name, value|
          header(name, value)
        end
      end

      def push_feature_flags(root_namespace = nil)
        Gitlab::AiGateway.push_feature_flag(:expanded_ai_logging, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_agentic_chat_openai_gpt_5, current_user)
        Gitlab::AiGateway.push_feature_flag(:use_generic_gitlab_api_tools, current_user)
        Gitlab::AiGateway.push_feature_flag(:ai_prompt_scanning, current_user)
        Gitlab::AiGateway.push_feature_flag(:dap_web_search, current_user)
        Gitlab::AiGateway.push_feature_flag(:dependency_bump_web_search, current_user)
        Gitlab::AiGateway.push_feature_flag(:dependency_bump_run_command, current_user)
        Gitlab::AiGateway.push_feature_flag(:ai_context_compaction, current_user)
        Gitlab::AiGateway.push_feature_flag(:agentic_foundational_flow_tool, current_user)
        Gitlab::AiGateway.push_feature_flag(:ai_gateway_multi_default_models, current_user)
        Gitlab::AiGateway.push_feature_flag(:duo_chat_clarification_question_tool, current_user)
        Gitlab::AiGateway.push_feature_flag(:software_development_flow_registry, current_user)
        return unless root_namespace

        Gitlab::AiGateway.push_feature_flag(:duo_agentic_chat_prefer_mcp_tools, root_namespace)
        Gitlab::AiGateway.push_feature_flag(:dw_read_blobs_api, root_namespace)
        # Kill switch: the gateway gates the blob read on this too, so disabling it
        # falls the gateway back to the full-checkpoint read.
        Gitlab::AiGateway.push_feature_flag(:duo_workflow_read_incremental_checkpoints, root_namespace)
      end

      def find_item_consumer!(consumer_id, project)
        consumer = ::Ai::Catalog::ItemConsumer.find(consumer_id)

        forbidden!('Agent or flow is not enabled for this project') unless consumer.project_id == project.id

        consumer
      rescue ActiveRecord::RecordNotFound
        not_found!('Enabled agent or flow was not found for this project.')
      end

      def container_access_allowed?(container)
        if container.is_a?(Project)
          current_user.can?(:read_project, container)
        else
          current_user.can?(:read_group, container)
        end
      end

      # Resolves the namespace ID from request params/headers.
      # The IDE sends namespace_id of the project's immediate group via header,
      # while the web agentic chat UI sends it as a query param.
      def request_namespace_id
        params[:root_namespace_id].presence ||
          params[:namespace_id].presence ||
          headers['X-Gitlab-Namespace-Id'].presence
      end

      # Resolves the namespace object from request params/headers.
      # Returns nil if namespace is not found or the user lacks read access.
      def find_request_namespace
        id = request_namespace_id
        return unless id

        namespace = find_namespace(id)
        return unless namespace &&
          Ability.allowed?(current_user, :read_group, namespace, composite_identity_check: false)

        namespace
      end

      def start_workflow_params(workflow_id, container:, service_account: nil)
        resolved_service_account = resolve_service_account(service_account)
        workflow_context_service = workflow_context_generation_service(
          container: container, service_account: resolved_service_account
        )

        oauth_token_result = workflow_context_service.generate_oauth_token_with_composite_identity_support
        if oauth_token_result.error?
          render_api_error!(oauth_token_result[:message], oauth_token_result[:http_status] || :forbidden)
        end

        workflow_token_result = workflow_context_service.generate_workflow_token
        handle_workflow_token_error(workflow_token_result) if workflow_token_result.error?

        {
          goal: params[:goal],
          workflow_id: workflow_id,
          workflow_oauth_token: oauth_token_result[:oauth_access_token].plaintext_token,
          workflow_service_token: workflow_token_result[:token],
          service_account: resolved_service_account,
          source_branch: params[:source_branch],
          additional_context: params[:additional_context],
          workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user,
            namespace: find_request_namespace || container.root_ancestor,
            project: find_project(params[:project_id].presence)).to_json,
          shallow_clone: params.fetch(:shallow_clone, true),
          duo_agent_platform_feature_setting: workflow_context_service.duo_agent_platform_feature_setting,
          **langsmith_trace_params
        }.merge(::Ai::DuoWorkflows::FoundationalFlowStartParamsResolver.call(params[:workflow_definition], container,
          user: current_user))
      end

      def langsmith_trace_params
        return {} unless headers['Langsmith-Trace'].present?

        { langsmith_trace: headers['Langsmith-Trace'] }
      end

      def workflow_context_generation_service(container: nil, service_account: nil)
        ::Ai::DuoWorkflows::WorkflowContextGenerationService.new(
          current_user: current_user,
          organization: container&.organization || ::Current.organization,
          workflow_definition: params[:workflow_definition],
          service_account: resolve_service_account(service_account),
          container: container,
          environment: params[:environment]
        )
      end

      def resolve_service_account(service_account = nil)
        service_account || service_account_from_composite_identity || duo_workflow_service_account
      end

      def duo_workflow_service_account
        project = find_project(params[:project_id]) if params[:project_id]
        organization = project&.organization || ::Current.organization
        service_account = ::Ai::Setting.for_organization_read_only(organization).duo_workflow_service_account_user
        return unless service_account

        ::Ai::ServiceAccountMemberAddService.new(project, service_account).execute if project
        service_account
      end

      def service_account_from_composite_identity
        service_account = ::Gitlab::Auth::Identity.resolve_composite_identity_actor(current_user)

        service_account if service_account.service_account?
      end

      def handle_workflow_token_error(result)
        message = result[:message]

        if message.include?("USAGE_QUOTA_EXCEEDED")
          message = "You don't have enough GitLab Credits to run this flow. " \
            "Contact your administrator for more credits."
          render_api_error!(message, :forbidden)
        else
          render_api_error!(message, :bad_request)
        end
      end

      # Authorization and the service account come from one call so they cannot derive
      # from different classifications.
      def authorize_flow_execution!(
        workflow_params, container, caller_can_execute:, start_workflow:, item_consumer_id:)
        result = ::Ai::DuoWorkflows::FlowExecutionAuthorizer.new(
          current_user: current_user,
          container: container,
          workflow_definition: workflow_params[:workflow_definition],
          start_workflow: start_workflow,
          item_consumer_id: item_consumer_id,
          caller_can_execute: caller_can_execute
        ).execute

        forbidden!(result.message) if result.error?

        service_account = result.payload[:service_account]
        workflow_params[:service_account] = service_account if service_account

        result.payload[:execution]
      end

      def resolve_workflow_definition(consumer)
        params[:workflow_definition] || consumer&.item&.foundational_flow_reference
      end

      def build_additional_context(consumer, additional_context)
        case resolve_workflow_definition(consumer)
        when ::Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION
          inject_secret_fp_detection_context(additional_context)
        else
          additional_context
        end
      end

      def inject_secret_fp_detection_context(additional_context)
        vulnerability = vulnerability_from_goal
        return additional_context unless vulnerability
        return additional_context unless Ability.allowed?(current_user, :read_vulnerability, vulnerability)

        raw_value = vulnerability.finding&.token_value
        return additional_context if raw_value.blank?

        # Raw Hash value (not a JSON string): the duo-cli executor reads `item.metadata`
        # and JSON-encodes it itself before sending to DWS.
        Array(additional_context) + [{
          category: 'secret_detection_context',
          content: { secret_value: raw_value }.to_json,
          "metadata" => { "version" => "1.0.0" }
        }]
      end

      def vulnerability_from_goal
        Vulnerability.find_by_id(params[:goal])
      end
      strong_memoize_attr :vulnerability_from_goal

      # Creates the Vulnerabilities::TriggeredWorkflow join row that links a
      # user-initiated Duo Workflow back to its target vulnerability so the row
      # surfaces in `Vulnerability.aiWorkflows`. The flag-driven workers create
      # this row themselves; the user-initiated API path did not, until now.
      def link_vulnerability_to_user_triggered_workflow(workflow)
        return unless workflow

        workflow_name = ::Vulnerabilities::TriggeredWorkflow::WORKFLOW_DEFINITIONS_TO_NAMES[workflow.workflow_definition]
        return unless workflow_name

        finding = vulnerability_from_goal&.finding
        return unless finding

        ::Vulnerabilities::TriggeredWorkflow.create!(
          vulnerability_occurrence_id: finding.id,
          workflow_id: workflow.id,
          workflow_name: workflow_name
        )
      rescue ActiveRecord::RecordInvalid => error
        ::Gitlab::ErrorTracking.track_exception(
          error,
          vulnerability_id: vulnerability_from_goal&.id,
          workflow_id: workflow&.id
        )
        nil
      end
    end
  end
end
