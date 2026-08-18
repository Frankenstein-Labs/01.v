# frozen_string_literal: true

module Ai
  module FlowTriggers
    class RunService
      include ::Gitlab::Utils::StrongMemoize
      include ::Ai::Catalog::Loggable
      include ::Gitlab::InternalEventsTracking

      # Flow definitions loaded from repository YAML are not schema-validated, so
      # id_tokens may be malformed or carry names that aren't valid CI variable
      # names. These bounds mirror the JSON schema constraints and are enforced
      # again here as a defence-in-depth measure before the names reach the CI
      # job hash.
      AutonomousTokenError = Class.new(StandardError)

      ID_TOKEN_NAME_REGEX = /\A[a-zA-Z_][a-zA-Z0-9_]*\z/
      MAX_ID_TOKENS = 20

      def initialize(project:, flow_trigger:, current_user: nil, resource: nil, trigger_source: :human)
        @project = project
        @current_user = current_user
        @resource = resource
        @flow_trigger = flow_trigger
        @trigger_source = trigger_source
        @service_account = flow_trigger.service_account
        @catalog_consumer = flow_trigger.ai_catalog_item_consumer
        @catalog_item = catalog_consumer&.item
        @catalog_item_pinned_version = catalog_consumer&.pinned_version_prefix

        ai_catalog_logger.context(consumer: catalog_consumer, item: catalog_item)

        link_composite_identity! if can_use_composite_identity?
      end

      def execute(params)
        # Adapter mode: a messaging adapter owns the progress/reply notes and the
        # lifecycle (it attached the binding). Skip the legacy CreateNoteService
        # and return [response, workflow] so the adapter's with_lifecycle_hooks
        # wrapper can drive on_flow_started / sync-failure.
        return execute_flow(params) if params[:messaging_callback_context]

        return execute_flow(params)[0] unless resource.is_a?(Noteable)

        # Flows that opt in (via suppress_mention_progress_note) manage their own
        # discussion threads, so skip the generic mention progress note for them.
        return execute_flow(params)[0] if skip_mention_progress_note?(params)

        note_service = ::Ai::FlowTriggers::CreateNoteService.new(
          project: project, resource: resource, author: service_account, discussion: params[:discussion]
        )

        note_service.execute(params) do |updated_params|
          execute_flow(updated_params)
        end
      end

      private

      def skip_mention_progress_note?(params)
        params[:event] == :mention && foundational_flow&.suppress_mention_progress_note
      end

      def execute_flow(params)
        if validation_error
          ai_catalog_logger.error(message: 'Flow trigger validation failed', error_message: validation_error.message)
          return [validation_error, nil]
        end

        response, workflow =
          if catalog_item&.flow?
            start_catalog_workflow(params)
          else
            run_workload(params)
          end

        ai_catalog_logger.error(message: 'Flow execution failed', error_message: response.message) if response.error?

        [response, workflow]
      end

      strong_memoize_attr def validation_error
        return autonomous_validation_error if autonomous_trigger?

        return ServiceResponse.error(message: 'cannot be triggered by non-human users') unless current_user&.human?

        return unless catalog_item&.third_party_flow? &&
          !Ability.allowed?(current_user, :execute_ai_catalog_item, catalog_consumer)

        ServiceResponse.error(message: 'current user not permitted to execute external agent')
      end

      def autonomous_trigger?
        trigger_source.in?([:system, :scheduled]) &&
          Feature.enabled?(:autonomous_service_account_execution, project)
      end

      attr_reader :project, :current_user, :resource, :flow_trigger, :trigger_source, :service_account,
        :catalog_item, :catalog_consumer, :catalog_item_pinned_version

      def sa_or_human_user
        autonomous_trigger? ? service_account : current_user
      end

      def create_workflow(params)
        workflow_params = {
          workflow_definition: "Trigger - #{flow_trigger.description}",
          status: :running,
          goal: params[:input],
          environment: :web,
          service_account: resolve_service_account(service_account)
        }

        if autonomous_trigger?
          workflow_params[:trigger_source] = trigger_source
          workflow_params[:trigger_flow_trigger_id] = flow_trigger.id
        end

        # For autonomous triggers, use the SA as the workflow creator
        result = ::Ai::DuoWorkflows::CreateWorkflowService.new(
          container: project,
          current_user: sa_or_human_user,
          params: workflow_params
        ).execute

        return ServiceResponse.error(message: result[:message]) if result.error?

        ServiceResponse.success(payload: { workflow: result[:workflow] })
      end

      def run_workload(params)
        flow_definition = fetch_flow_definition
        return ServiceResponse.error(message: 'invalid or missing flow definition') unless flow_definition

        wf_create_result = create_workflow(params)
        return wf_create_result unless wf_create_result.success?

        workflow = wf_create_result.payload[:workflow]

        token_result = inject_gateway_token(flow_definition, params, workflow)
        return token_result if token_result&.error?

        branch_result = branch_args
        return branch_result unless branch_result.success?

        response = execute_workload(flow_definition, params, branch_result.payload[:ref])

        handle_workload_response(response, workflow, params)
      end

      def inject_gateway_token(flow_definition, params, workflow)
        return unless flow_definition['injectGatewayToken'] == true

        token_response = ::Ai::ThirdPartyAgents::TokenService.new(
          current_user: current_user,
          project: project,
          organization: project.organization,
          agent_name: catalog_item&.name,
          workflow_id: workflow.id
        ).direct_access_token

        return token_response if token_response.error?

        params[:token] = token_response.payload
        nil
      end

      def execute_workload(flow_definition, params, ref)
        id_tokens = sanitize_id_tokens(flow_definition['id_tokens'])

        workload_definition = ::Ci::Workloads::WorkloadDefinition.new do |d|
          d.image = flow_definition['image']
          d.commands = flow_definition['commands']
          d.id_tokens = id_tokens
          d.variables = build_variables(params)
          d.tags = [::Ai::DuoWorkflows::Workflow::WORKLOAD_TAG]
          # Pass report_artifacts through with only a type guard. Detailed
          # validation (allowed report types, path format, etc.) is handled
          # by CI's pipeline config parser (Gitlab::Ci::Config::Entry::Reports)
          # when the workload YAML is processed. Invalid entries cause a loud
          # pipeline creation failure with a clear error message, which is
          # preferable to silently dropping misconfigured entries.
          reports = flow_definition['report_artifacts']
          d.artifacts_reports = reports if reports.is_a?(Hash) && reports.present?
        end

        ::Ci::Workloads::RunWorkloadService.new(
          project: project,
          current_user: service_account,
          source: :duo_workflow,
          workload_definition: workload_definition,
          ci_variables_included: flow_definition['variables'] || [],
          ref: ref
        ).execute
      end

      # Keep only well-formed entries: a valid CI variable name mapping to a Hash
      # whose `aud` is a string or a non-empty array of strings, mirroring the
      # JSON schema.
      def sanitize_id_tokens(id_tokens)
        return unless id_tokens.is_a?(Hash)

        sanitized = id_tokens.select do |name, value|
          name.to_s.match?(ID_TOKEN_NAME_REGEX) && value.is_a?(Hash) && valid_aud?(value['aud'])
        end.first(MAX_ID_TOKENS).to_h

        sanitized.presence
      end

      # The JSON schema constrains `aud` to a string or a non-empty array of
      # unique strings. Flow definitions from repository YAML bypass that schema,
      # so re-check the shape here before the value reaches the CI job hash.
      def valid_aud?(aud)
        case aud
        when String
          aud.present?
        when Array
          aud.present? && aud.all? { |entry| entry.is_a?(String) && entry.present? }
        else
          false
        end
      end

      def handle_workload_response(response, workflow, params)
        if response.success?
          workflow.workflows_workloads.create(project_id: project.id,
            workload_id: response.payload.id)

          log_external_agent_execution
          track_external_agent_execution(params)
        end

        status_event = response.success? ? "start" : "drop"
        ::Ai::DuoWorkflows::UpdateWorkflowStatusService.new(
          workflow: workflow, status_event: status_event, current_user: sa_or_human_user
        ).execute

        [response, workflow]
      end

      def start_catalog_workflow(params)
        execute_params = {
          item_consumer: catalog_consumer,
          flow: catalog_item,
          service_account: service_account,
          flow_version: catalog_item.resolve_version(catalog_item_pinned_version),
          event_type: params[:event].to_s,
          user_prompt: catalog_item_user_prompt(params[:input], params[:event], params),
          triggering_conversation: mention_triggering_conversation(params),
          execute_workflow: true,
          source_branch: source_branch,
          additional_context: additional_context
        }

        if params[:messaging_callback_context]
          execute_params[:messaging_callback_context] = params[:messaging_callback_context]
        end

        execute_params[:issue_id] = resource.iid if resource.is_a?(Issue)
        execute_params[:merge_request_id] = resource.iid if resource.is_a?(MergeRequest)

        response = ::Ai::Catalog::Flows::ExecuteService.new(
          project: project,
          current_user: sa_or_human_user,
          params: execute_params
        ).execute

        workflow = response.payload[:workflow]

        [response, workflow]
      end

      # For mention triggers params[:input] carries the conversation context built from
      # the triggering note (see EE::Notes::PostProcessService#mention_run_params), so it
      # is forwarded for the flow to answer the developer's question. For every other
      # event type the input is not a comment (e.g. the issuable iid for reviewer
      # assignment, raw hook data for webhook triggers) and nothing is forwarded.
      def mention_triggering_conversation(params)
        return unless params[:event].to_s == 'mention'

        params[:input]
      end

      def fetch_flow_definition
        return catalog_item.definition(catalog_item_pinned_version) if catalog_item&.third_party_flow?

        root_ref = project.repository.root_ref
        flow_definition_yaml = project.repository.blob_data_at(root_ref, flow_trigger.config_path)
        return unless flow_definition_yaml

        flow_definition = YAML.safe_load(flow_definition_yaml)
        return unless flow_definition.is_a?(Hash)

        flow_definition
      rescue Psych::Exception => e
        ai_catalog_logger.error(message: 'Failed to parse flow definition YAML', error_message: e.message)
        nil
      end

      def build_variables(params)
        # For autonomous triggers, the SA is both author and committer.
        # For human triggers, the SA authors and the human commits.
        committer = sa_or_human_user
        token = autonomous_trigger? ? autonomous_execution_token : composite_identity_token

        base_variables = {
          AI_FLOW_CONTEXT: serialized_resource,
          AI_FLOW_DISCUSSION_ID: params[:discussion_id],
          AI_FLOW_EVENT: params[:event].to_s,
          AI_FLOW_GITLAB_TOKEN: token,
          AI_FLOW_INPUT: params[:input],
          AI_FLOW_PROJECT_PATH: project.full_path,
          AI_FLOW_GITLAB_HOSTNAME: gitlab_hostname,
          GIT_AUTHOR_NAME: git_user_name(service_account),
          GIT_AUTHOR_EMAIL: git_user_email(service_account),
          GIT_COMMITTER_NAME: git_user_name(committer),
          GIT_COMMITTER_EMAIL: git_user_email(committer)
        }

        if params.key?(:token)
          gateway_token = params[:token]

          headers_string = if gateway_token[:headers].present?
                             gateway_token[:headers].filter_map { |k, v| "#{k}: #{v}" if v.present? }.join("\n")
                           else
                             ''
                           end

          base_variables.merge!({
            AI_FLOW_AI_GATEWAY_TOKEN: gateway_token[:token],
            AI_FLOW_AI_GATEWAY_HEADERS: headers_string
          })
        end

        base_variables
      end

      def branch_args
        workload_branch_service = ::Ci::Workloads::WorkloadBranchService.new(
          current_user: service_account,
          project: project,
          source_branch: source_branch
        )
        branch_response = workload_branch_service.execute
        return branch_response unless branch_response.success?

        ServiceResponse.success(payload: { ref: branch_response.payload[:ref] })
      end

      def autonomous_validation_error
        validator = Ai::FlowTriggers::AutonomousServiceAccountEligibilityValidator.new(service_account, project)
        return ServiceResponse.error(message: validator.errors.full_messages.join(', ')) unless validator.valid?

        if catalog_item&.third_party_flow? &&
            !Ability.allowed?(service_account, :execute_ai_catalog_item, catalog_consumer)
          return ServiceResponse.error(message: 'service account not permitted to execute external agent')
        end

        nil
      end

      def autonomous_execution_token
        result = ::Ai::DuoWorkflows::CreateAutonomousOauthAccessTokenService.new(
          service_account: service_account,
          organization: project.organization,
          container: project,
          trigger_source: trigger_source
        ).execute

        raise AutonomousTokenError, result.message if result.error?

        result[:oauth_access_token].plaintext_token
      end

      def composite_identity_token
        return unless can_use_composite_identity?

        composite_oauth_token_result = ::Ai::DuoWorkflows::CreateCompositeOauthAccessTokenService.new(
          current_user: current_user,
          organization: project.organization,
          service_account: service_account
        ).execute

        return if composite_oauth_token_result.error?

        composite_oauth_token_result[:oauth_access_token].plaintext_token
      end

      def can_use_composite_identity?
        return false unless current_user
        return false if ai_settings.duo_workflow_oauth_application.nil?

        service_account.composite_identity_enforced?
      end

      def ai_settings
        Ai::Setting.for_organization_read_only(project.organization)
      end

      def link_composite_identity!
        identity = ::Gitlab::Auth::Identity.fabricate(service_account)
        identity.link!(current_user) if identity&.composite?
      end

      def serialized_resource
        return unless resource

        wrapped = ::Ai::AiResource::Wrapper.new(sa_or_human_user, resource).wrap
        wrapped&.serialize_for_ai&.to_json
      end

      def gitlab_hostname
        host = Gitlab.config.gitlab.host
        port = Gitlab.config.gitlab.port

        return host if [80, 443].include?(port)

        "#{host}:#{port}"
      end

      def git_user_email(user)
        return "" unless user.respond_to?(:commit_email_or_default)

        user.commit_email_or_default
      end

      def git_user_name(user)
        return "" unless user.respond_to?(:name)

        user.name
      end

      def catalog_item_user_prompt(user_input, event_type, params = {})
        goal_template_class = foundational_flow&.goal_templates

        if goal_template_class.present?
          goal_template_class.resolve(
            event_type: event_type,
            resource: resource,
            user_input: user_input,
            params: params
          )
        elsif event_type == :mention
          ::Ai::Catalog::GoalTemplates::Base.default_mention_goal(
            resource: resource,
            user_input: user_input
          )
        elsif foundational_flow?
          Gitlab::UrlBuilder.build(@resource)
        else
          user_input
        end
      end

      def foundational_flow
        return unless @catalog_item&.foundational_flow_reference.present?

        ::Ai::Catalog::FoundationalFlow[@catalog_item.foundational_flow_reference]
      end
      strong_memoize_attr :foundational_flow

      def foundational_flow?
        foundational_flow.present?
      end

      def source_branch
        case resource
        when ::Ci::Pipeline then resource.source_ref
        when ::MergeRequest then resource.source_branch
        end
      end

      def additional_context
        contexts = []
        contexts.concat(pipeline_additional_context) if resource.is_a?(::Ci::Pipeline)
        contexts.concat(foundational_flow.resolve_additional_context_for(resource: resource)) if foundational_flow?
        contexts.presence
      end

      def pipeline_additional_context
        merge_request = resource.all_merge_requests_by_recency.opened.first
        merge_request_context =
          if merge_request
            {
              "url" => ::Gitlab::UrlBuilder.build(merge_request),
              "author_id" => merge_request.author_id.to_s
            }
          else
            { "url" => "" }
          end

        # Lowercase "metadata" key with a raw Hash value (not a JSON string): the duo-cli
        # executor reads `item.metadata` and JSON-encodes it itself before sending to DWS.
        [
          {
            "Category" => "merge_request",
            "Content" => ::Gitlab::Json.dump(merge_request_context),
            "metadata" => { "version" => "1.0.0" }
          },
          {
            "Category" => "pipeline",
            "Content" => ::Gitlab::Json.dump({ "source_branch" => resource.source_ref, "source" => resource.source }),
            "metadata" => { "version" => "1.0.0" }
          }
        ]
      end

      def log_external_agent_execution
        ai_catalog_logger.info(message: 'External agent executed') if catalog_item
      end

      def track_external_agent_execution(params)
        return unless catalog_item

        event_properties = Ai::Catalog::Tracking::EventPropertiesBuilder
          .new(item: catalog_item, version: catalog_item.resolve_version(catalog_item_pinned_version))
          .to_h

        track_internal_event(
          'trigger_ai_catalog_item',
          user: sa_or_human_user,
          project: project,
          additional_properties: event_properties.merge(
            label: catalog_item.item_type,
            property: params[:event].to_s,
            value: catalog_item.id
          )
        )
      end

      def resolve_service_account(service_account)
        return unless service_account.service_account?

        service_account
      end
    end
  end
end
