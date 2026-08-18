# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class CreateWorkflowService
      include ::Services::ReturnServiceResponses
      include Concerns::WorkflowEventTracking
      include Concerns::GovernanceResolution

      # `execution` is a FlowExecutionAuthorizer::Classification. Anything else,
      # nil or a raw value, gets the strictest access check.
      def initialize(container:, current_user:, params:, execution: nil)
        @container = container || current_user.default_duo_namespace
        @current_user = current_user
        @execution = execution
        # Remove ids to avoid confusion - @container determines the workflow scope, not raw IDs
        @params = params.except(:namespace_id, :project_id)
      end

      def execute
        unless @container.is_a?(::Project) || @container.is_a?(::Namespace)
          return error('container must be a Project or Namespace', :bad_request)
        end

        resolve_agent_privileges

        namespace = @container.is_a?(::Project) ? @container.namespace : @container
        credit_check_response = Ai::UsageQuotaService.new(
          user: @current_user,
          namespace: namespace,
          workflow_definition: workflow_definition
        ).execute

        if credit_check_response.error?
          # http status should not be part of Service, but needs significant refactoring in the callers of
          # CreateWorkflowService.execute
          http_status = http_status_for_quota_error(credit_check_response.reason)
          message = enriched_error_message(credit_check_response)
          return error(message, http_status, pass_back: { reason: credit_check_response.reason })
        end

        response = check_ai_catalog_item_access || check_access
        return response if response&.error?

        workflow = Ai::DuoWorkflows::Workflow.new(workflow_attributes)

        return error(workflow.errors.full_messages.join(', '), :bad_request) unless workflow.save

        link_source_work_item(workflow)
        link_source_merge_request(workflow)
        link_source_pipeline(workflow)

        Ai::DuoWorkflows::GenerateWorkflowTitleWorker.perform_async(workflow.id)

        track_workflow_event("agent_platform_session_created", workflow, source: @params[:source])

        audit_context = {
          name: 'duo_session_created',
          author: @current_user,
          scope: workflow.project || workflow.namespace,
          target: workflow,
          target_details: "#{workflow.workflow_definition} session #{workflow.id}",
          message: 'Created Duo session'
        }
        begin
          ::Gitlab::Audit::Auditor.audit(audit_context)
        rescue StandardError => e
          Gitlab::ErrorTracking.track_exception(e, workflow_id: workflow.id)
        end

        create_workflow_system_note(workflow)

        unless ::Gitlab::ClickHouse.globally_enabled_for_analytics?
          Ai::DuoWorkflows::SyncSessionArtifactWorker.perform_async(workflow.id)
        end

        success(workflow: workflow)
      end

      def workflow_attributes
        base_params.merge(
          user: @current_user,
          incremental_checkpoints_enabled: Workflow.incremental_checkpoints_enabled_for?(@container),
          **container_attributes,
          **noteable_attributes,
          **service_account_attributes
        )
      end

      private

      def link_source_work_item(workflow)
        return unless workflow.work_item

        ::Ai::DuoWorkflows::LinkArtifactService.new(
          workflow: workflow,
          artifact: workflow.work_item,
          link_type: :source
        ).execute
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(err, workflow_id: workflow.id)
      end

      def link_source_merge_request(workflow)
        return unless workflow.merge_request

        ::Ai::DuoWorkflows::LinkArtifactService.new(
          workflow: workflow,
          artifact: workflow.merge_request,
          link_type: :source
        ).execute
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(err, workflow_id: workflow.id)
      end

      def link_source_pipeline(workflow)
        pipeline = resolve_source_pipeline
        return unless pipeline

        ::Ai::DuoWorkflows::LinkArtifactService.new(
          workflow: workflow,
          artifact: pipeline,
          link_type: :source
        ).execute
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(err, workflow_id: workflow.id)
      end

      def resolve_source_pipeline
        return unless @container.is_a?(::Project)

        flow = ::Ai::Catalog::FoundationalFlow[workflow_definition]
        flow&.resolve_source_pipeline_for(project: @container, goal: @params[:goal])
      end

      def base_params
        @params.except(:issue_id, :merge_request_id, :service_account, :source)
      end

      def service_account_attributes
        return {} unless @params[:service_account]

        { service_account: @params[:service_account] }
      end

      def create_workflow_system_note(workflow)
        noteable = workflow.noteable
        return unless noteable
        return if workflow.suppress_agent_session_note?

        # Who/what initiated the workflow
        # currently the user, but could be another agent
        # in future iterations
        trigger_source = @current_user
        note_author = workflow.service_account

        SystemNoteService.agent_session_started(
          noteable,
          noteable.project,
          workflow.id,
          trigger_source,
          note_author
        )
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(
          err,
          workflow_id: workflow.id,
          noteable_type: noteable.class.name,
          noteable_id: noteable.id
        )
      end

      def check_ai_catalog_item_access
        return unless @params[:ai_catalog_item_version]

        finder_params = {
          item_id: @params[:ai_catalog_item_version].ai_catalog_item_id
        }

        if @container.is_a?(::Project)
          finder_params[:project_id] = @container.id
        elsif @container.is_a?(::Namespace)
          finder_params[:group_id] = @container.id
        end

        return if Ai::Catalog::ItemConsumersFinder.new(@current_user, params: finder_params).execute.exists?

        error('ItemVersion not found', :not_found)
      end

      def check_access
        if chat?
          check_agentic_chat_access
        else
          check_duo_workflow_access
        end
      end

      def check_agentic_chat_access
        unless Ability.allowed?(@current_user, :access_duo_agentic_chat, @container)
          return error('forbidden to access agentic chat', :forbidden)
        end

        reference = FoundationalChatAgent.reference_from_workflow_definition(workflow_definition)

        agent = FoundationalChatAgent.with_workflow_definition(workflow_definition)
        if agent&.ultimate_only
          root_namespace = @container.root_ancestor
          return error('agent requires Ultimate plan', :forbidden) unless
            root_namespace.licensed_feature_available?(:ai_features)
        end

        return if foundational_agents_settings_container&.foundational_agent_enabled?(reference)

        error('foundation agent disabled for namespace', :forbidden)
      end

      def check_duo_workflow_access
        return if Ability.allowed?(@current_user, duo_workflow_ability, @container)

        error('forbidden to access duo workflow', :forbidden, pass_back: { reason: :cannot_create_workflow_pipeline })
      end

      # :create_duo_workflow_for_ci is :duo_workflow plus the minimum role for
      # asynchronous execution, which a run the caller performs itself is not.
      def duo_workflow_ability
        client_executed? ? :duo_workflow : :create_duo_workflow_for_ci
      end

      def client_executed?
        @execution.is_a?(FlowExecutionAuthorizer::Classification) && @execution.client_executed?
      end

      def workflow_definition
        @params['workflow_definition'] || @params[:workflow_definition]
      end

      def chat?
        FoundationalChatAgent.foundational_workflow_definition?(workflow_definition)
      end

      def container_attributes
        if @container.is_a?(::Project)
          { project: @container }
        elsif @container.is_a?(::Namespace)
          { namespace: @container }
        end
      end

      def noteable_attributes
        attributes = {}

        if @params[:issue_id].present?
          work_item = find_issue(@params[:issue_id])
          attributes[:issue_id] = work_item.id if work_item
        end

        if @params[:merge_request_id].present?
          mr = find_merge_request(@params[:merge_request_id])
          attributes[:merge_request_id] = mr.id if mr
        end

        # When no explicit noteable is provided, resolve from the foundational flow.
        # E.g. fix_pipeline derives merge_request from the pipeline URL (goal).
        # Also skip resolution when the API layer has already resolved AR objects
        # (e.g. agent_workflows passes :issue or :merge_request directly).
        resolve_noteable_from_flow(attributes) unless explicit_noteable?(attributes)

        attributes
      end

      def explicit_noteable?(attributes)
        attributes.any? || @params[:issue].present? || @params[:merge_request].present?
      end

      def resolve_noteable_from_flow(attributes)
        return unless @container.is_a?(::Project)

        flow = ::Ai::Catalog::FoundationalFlow[workflow_definition]
        noteable = flow&.resolve_noteable_for(project: @container, goal: @params[:goal])

        attributes[:merge_request_id] = noteable.id if noteable.is_a?(::MergeRequest)
      end

      def find_issue(issue_iid)
        return unless @container.is_a?(::Project)

        IssuesFinder.new(@current_user, project_id: @container.id, iids: [issue_iid]).execute.first
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(err, issue_iid: issue_iid, container_id: @container.id)
        nil
      end

      def find_merge_request(mr_iid)
        MergeRequestsFinder.new(@current_user, project_id: @container.id, iids: [mr_iid]).execute.first
      rescue StandardError => err
        Gitlab::ErrorTracking.track_exception(err, merge_request_iid: mr_iid, project_id: @container.id)
        nil
      end

      def enriched_error_message(response)
        case response.reason
        when :namespace_missing
          ::Ai::FoundationalFlowMessages.namespace_missing_error(@current_user)
        when :usage_billing_forbidden
          ::Ai::FoundationalFlowMessages.usage_billing_forbidden_error
        else
          response.message
        end
      end

      def http_status_for_quota_error(reason)
        case reason
        when :user_missing, :namespace_missing
          :bad_request
        when :usage_quota_exceeded
          :payment_required
        when :usage_billing_forbidden
          :forbidden
        else
          :internal_server_error
        end
      end

      def foundational_agents_settings_container
        @current_user.duo_foundational_agents_container(@container.root_ancestor)
      end

      def resolve_agent_privileges
        return unless @container
        return unless valid_container_for_governance?

        return clamp_client_privileges if @params[:agent_privileges]

        unless Feature.enabled?(:gitlab_duo_governance_settings, @container)
          @params[:agent_privileges] = ::Ai::DuoWorkflows::Workflow::AgentPrivileges::DEFAULT_PRIVILEGES
          return
        end

        result = execute_governance_resolution_with_retry

        if result&.success?
          @params[:agent_privileges] = result.payload[:agent_privileges]
          @params[:pre_approved_agent_privileges] = result.payload[:pre_approved_agent_privileges]
        else
          Gitlab::AppLogger.error(
            message: "Governance resolution failed after #{MAX_GOVERNANCE_RETRIES} " \
              "retries, failing closed with no tools",
            container_id: @container.id,
            container_type: @container.class.name
          )
          @params[:agent_privileges] = []
          @params[:pre_approved_agent_privileges] = []
        end
      end

      # Local-surface clients (IDE, CLI) supply their own agent_privileges, but
      # cannot be trusted to self-report them: governance is the ceiling.
      # Intersect the client-supplied privileges with the governance resolution
      # for the workflow's surface (most-restrictive-wins), so an admin `deny`
      # always holds. Web surfaces keep their existing trusted behavior because
      # the web UI only submits privileges it resolved from governance itself.
      def clamp_client_privileges
        return if web_surface?
        return unless Feature.enabled?(:gitlab_duo_governance_settings, @container)
        return unless Feature.enabled?(:duo_workflow_local_tool_governance, @container.root_ancestor)

        result = execute_governance_resolution_with_retry(surface: clamp_surface)

        if result&.success?
          @params[:agent_privileges] &= result.payload[:agent_privileges]

          # Always set pre-approved privileges: leaving them unset would let the
          # DB column default apply unclamped. When adopting the resolved list,
          # constrain it to the clamped grants (a model invariant).
          @params[:pre_approved_agent_privileges] =
            if @params[:pre_approved_agent_privileges]
              @params[:pre_approved_agent_privileges] & result.payload[:pre_approved_agent_privileges]
            else
              result.payload[:pre_approved_agent_privileges] & @params[:agent_privileges]
            end
        else
          Gitlab::AppLogger.error(
            message: "Governance resolution failed after #{MAX_GOVERNANCE_RETRIES} " \
              "retries, failing closed with no privileges",
            container_id: @container.id,
            container_type: @container.class.name
          )
          @params[:agent_privileges] = []
          @params[:pre_approved_agent_privileges] = []
        end
      end

      def web_surface?
        surface = @params[:environment].presence || :web

        ::Ai::ToolRule::WEB_SURFACES.include?(surface.to_s)
      end

      # Unrecognized environments (notably `external`) clamp against web rules,
      # matching the surface the JWT-claim mint resolves for them.
      def clamp_surface
        ::Ai::ToolRules::GovernanceSurface.for(
          environment: @params[:environment],
          container: @container,
          workflow_definition: workflow_definition
        ) || :web
      end

      def execute_governance_resolution_with_retry(surface: nil)
        resolve_governance_with_retry(
          build_resolution_service(surface: surface),
          container_id: @container.id,
          container_type: @container.class.name
        )
      end

      def build_resolution_service(surface: nil)
        surface ||= ::Ai::ToolRules::GovernanceSurface.for(
          environment: @params[:environment],
          container: @container,
          workflow_definition: workflow_definition
        ) || degraded_surface

        ::Ai::ToolRules::ResolutionService.new(
          namespace: @container.root_ancestor,
          surface: surface,
          project: @container.is_a?(::Project) ? @container : nil
        )
      end

      # Surface to use when background governance does not apply (flag off, or a
      # non-background environment). The environment passes through to its default
      # surface (ambient/web route to web_access), matching the pre-flag behaviour.
      def degraded_surface
        env = @params[:environment]&.to_s
        env.presence || 'web'
      end

      def valid_container_for_governance?
        @container.is_a?(::Project) || @container.is_a?(::Namespace)
      end
    end
  end
end
