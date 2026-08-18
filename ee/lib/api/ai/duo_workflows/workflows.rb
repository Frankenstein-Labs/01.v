# frozen_string_literal: true

module API
  module Ai
    module DuoWorkflows
      class Workflows < ::API::Base
        include PaginationParams
        include APIGuard

        HEADERS_TO_FORWARD_AS_GRPC_METADATA = %w[
          X-Gitlab-Language-Server-Version
          X-Gitlab-Client-Type
          Langsmith-Trace
          X-Gitlab-Client-Name
          X-Gitlab-Client-Version
          X-Gitlab-Tracking-Context
        ].freeze

        TRACE_MAX_RESPONSE_BYTESIZE = 25.megabytes

        # Channels exposed to non-owner readers of a pipeline-triggered workflow.
        # Other channels (e.g. conversation_history, handover) carry raw tool
        # outputs that may include secrets or repository contents and are only
        # returned to the workflow owner.
        TRACE_SAFE_CHANNELS = %w[ui_chat_log plan status].freeze

        RESOLVE_DEPENDENCY_BUMP_WORKFLOW_DEFINITION =
          ::DependencyManagement::SecurityUpdate::TriggerResolveDependencyBumpWorkflowWorker::WORKFLOW_DEFINITION

        WORKFLOW_EVENTS = {
          ::Vulnerabilities::TriggerFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION =>
            'trigger_sast_vulnerability_fp_detection_workflow',
          ::Vulnerabilities::TriggerResolutionWorkflowWorker::WORKFLOW_DEFINITION =>
            'trigger_sast_vulnerability_resolution_workflow',
          ::Vulnerabilities::TriggerSecretDetectionFalsePositiveDetectionWorkflowWorker::WORKFLOW_DEFINITION =>
            'trigger_secret_detection_vulnerability_fp_detection_workflow',
          RESOLVE_DEPENDENCY_BUMP_WORKFLOW_DEFINITION =>
            'trigger_resolve_dependency_bump_workflow'
        }.freeze

        WORKFLOW_ACTIONS_SOURCE = %w[
          merge_request_code_conflict
          merge_request_dependency_bump
          merge_request_fix_pipeline
          merge_request_resolve_discussion
          work_item_to_merge_request
          fix_pipeline
          convert_platform_ci_pipeline
        ].freeze

        helpers ::API::Helpers::DuoWorkflowHelpers
        helpers Gitlab::InternalEventsTracking

        feature_category :duo_agent_platform

        allow_access_with_scope :ai_workflows, if: ->(request) do
          return false unless request.get?

          ws_path = Gitlab::Utils.append_path(
            Gitlab.config.gitlab.relative_url_root, '/api/v4/ai/duo_workflows/ws')
          trace_base = Gitlab::Utils.append_path(
            Gitlab.config.gitlab.relative_url_root, '/api/v4/ai/duo_workflows/workflows/')
          trace_path_pattern = %r{\A#{Regexp.escape(trace_base)}\d+/trace\.jsonl\z}

          request.path == ws_path || request.path.match?(trace_path_pattern)
        end

        before do
          authenticate!
        end

        helpers do
          # Prefers the most specific (subgroup) namespace from namespace_id/header,
          # falling back to root_namespace_id. Use this when checking cascading
          # settings that subgroups can override.
          def find_most_specific_namespace
            subgroup_id = params[:namespace_id].presence ||
              headers['X-Gitlab-Namespace-Id'].presence

            if subgroup_id
              ns = find_namespace(subgroup_id)

              if ns.nil?
                Gitlab::AppLogger.warn(
                  message: 'Namespace not found, falling back to root namespace',
                  namespace_id: subgroup_id
                )
              elsif !Ability.allowed?(current_user, :read_group, ns, composite_identity_check: false)
                Gitlab::AppLogger.warn(
                  message: 'User lacks permission on namespace, falling back to root namespace',
                  namespace_id: subgroup_id
                )
              else
                return ns
              end
            end

            find_request_namespace
          end

          def most_specific_namespace_or_root(root_namespace)
            find_most_specific_namespace || root_namespace
          end

          def find_root_namespace!
            namespace_id = request_namespace_id

            # First find the namespace (returns nil if not found)
            namespace = namespace_id && find_namespace(namespace_id)
            return current_user.governing_namespace unless namespace

            # Then enforce authorization (raises 404 if no access)
            not_found!('Namespace') unless Ability.allowed?(
              current_user, :read_group, namespace, composite_identity_check: false)

            root_namespace = namespace.root_ancestor

            # Validate namespace is contextually relevant to prevent
            # unauthorized access to model settings from unrelated namespaces
            validate_namespace_context!(root_namespace)

            root_namespace
          end

          def validate_namespace_context!(namespace)
            # If working in a project context, namespace must be the project's root namespace
            if params[:project_id].presence
              project = find_project!(params[:project_id])
              forbidden!("Namespace does not match project context") unless namespace.id == project.root_namespace.id
            end

            # If working in a namespace context (without project), must match or be ancestor
            return unless params[:namespace_id].presence

            context_namespace = find_namespace(params[:namespace_id])
            not_found!('Namespace') unless Ability.allowed?(
              current_user, :read_group, context_namespace, composite_identity_check: false)

            return if namespace.id == context_namespace.root_ancestor.id

            forbidden!("Namespace does not match workflow context")
          end

          def cloud_service_for_self_hosted_config(feature_setting, cloud_connector_headers)
            return unless ::Ai::SelfHostedDapBilling.should_bill?(feature_setting)

            {
              Headers: cloud_connector_headers.merge(
                'authorization' => "Bearer #{::CloudConnector::Tokens.cloud_connector_token}"
              ),
              URI: Gitlab::DuoWorkflow::Client.cloud_connected_url(user: current_user),
              Secure: true
            }
          end

          def find_feature_setting_name
            # This header is sent only from the Node Executor.
            feature_setting_name_from_header =
              headers['X-Gitlab-Agent-Platform-Feature-Setting-Name'].presence

            # We treat agentic chat as the default feature for the /ws endpoint if
            # no header is present.
            (feature_setting_name_from_header ||
              ::Ai::ModelSelection::FeaturesConfigurable.agentic_chat_feature_name).to_sym
          end

          def find_user_selected_model_identifier
            # Currently, only the web agentic chat UI sends this attribute, as a query param.
            # The IDE does not yet send this attribute.
            params[:user_selected_model_identifier].presence
          end

          def find_workflow!(id)
            workflow = ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, id)
            return workflow if current_user.can?(:read_duo_workflow, workflow)

            forbidden!
          end

          def get_current_organization_id
            Current.organization.id if Current.organization_assigned
          end

          def find_catalog_consumer_for_workflow!(workflow)
            catalog_item = workflow.ai_catalog_item_version&.item
            not_found!('AI Catalog item not found for this workflow') unless catalog_item

            consumer = ::Ai::Catalog::ItemConsumersFinder.new(current_user, params: {
              project_id: workflow.project.id,
              item_id: catalog_item.id,
              include_inherited: true
            }).execute.first

            not_found!('AI Catalog consumer not found for this workflow') unless consumer

            consumer
          end

          def gitlab_oauth_token(workflow_context_service = nil)
            workflow_context_service ||= workflow_context_generation_service

            # TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/581556
            # It should be if find_feature_setting_name == FeaturesConfigurable.agentic_chat_feature_name
            oauth_token_result =
              if headers['X-Gitlab-Agent-Platform-Feature-Setting-Name'].present?
                workflow_context_service.generate_oauth_token_with_composite_identity_support
              else
                workflow_context_service.generate_oauth_token
              end

            if oauth_token_result.error?
              render_api_error!(oauth_token_result[:message], oauth_token_result[:http_status] || :forbidden)
            end

            oauth_token_result[:oauth_access_token]
          end

          def duo_workflow_token(container: nil)
            workflow_context_service = workflow_context_generation_service(container: container)
            workflow_token_result = workflow_context_service.generate_workflow_token
            bad_request!(workflow_token_result[:message]) if workflow_token_result.error?

            workflow_token_result
          end

          def duo_workflow_list_tools
            duo_workflow_list_tools_result = ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
              duo_workflow_service_url: Gitlab::DuoWorkflow::Client.url(user: current_user),
              current_user: current_user,
              secure: Gitlab::DuoWorkflow::Client.secure?(feature_setting: nil)
            ).list_tools
            bad_request!(duo_workflow_list_tools_result[:message]) if duo_workflow_list_tools_result[:status] == :error

            duo_workflow_list_tools_result
          end

          def create_workflow_params
            wrkf_params = declared_params(include_missing: false).except(
              :start_workflow,
              :source_branch,
              :additional_context,
              :shallow_clone,
              :ai_catalog_item_consumer_id
            )

            if wrkf_params[:ai_catalog_item_version_id]
              wrkf_params[:ai_catalog_item_version] = ::Ai::Catalog::ItemVersion
                                                        .find(wrkf_params.delete(:ai_catalog_item_version_id))
            end

            if wrkf_params[:issue_id] && wrkf_params[:project_id]
              project = find_project!(wrkf_params[:project_id])
              wrkf_params[:issue] = project.issues.find_by_iid!(wrkf_params.delete(:issue_id))
            end

            if wrkf_params[:merge_request_id] && wrkf_params[:project_id]
              project = find_project!(wrkf_params[:project_id])
              wrkf_params[:merge_request] = project.merge_requests.find_by_iid!(wrkf_params.delete(:merge_request_id))
            end

            wrkf_params
          end

          def track_event(consumer: nil, workflow: nil)
            workflow_definition = resolve_workflow_definition(consumer)
            return unless workflow_definition && WORKFLOW_EVENTS.key?(workflow_definition)

            if workflow_definition == RESOLVE_DEPENDENCY_BUMP_WORKFLOW_DEFINITION
              track_resolve_dependency_bump_event(workflow)
            else
              track_vulnerability_event(WORKFLOW_EVENTS[workflow_definition])
            end
          end

          def track_vulnerability_event(event_name)
            vulnerability = vulnerability_from_goal
            return unless vulnerability

            track_internal_event(
              event_name,
              project: vulnerability.project,
              additional_properties: {
                label: 'manual',
                value: vulnerability.id,
                property: vulnerability.severity
              }
            )
          end

          # Only use the project when the caller can read it and it's inside the namespace, so a foreign
          # or unreadable project_id can't sway governance.
          def request_project_within(namespace)
            project = find_project(params[:project_id].presence)
            return unless project && can?(current_user, :read_project, project)
            return unless namespace && project.root_ancestor.id == namespace.root_ancestor.id

            project
          end

          def track_resolve_dependency_bump_event(workflow)
            return unless workflow

            merge_request = workflow.merge_request

            track_internal_event(
              WORKFLOW_EVENTS[RESOLVE_DEPENDENCY_BUMP_WORKFLOW_DEFINITION],
              project: workflow.project,
              additional_properties: {
                label: 'manual',
                value: merge_request&.id,
                property: merge_request ? resolve_dependency_bump_iteration(merge_request).to_s : nil
              }.compact
            )
          end

          # Iteration = number of resolve_dependency_bump workflows that exist for
          # the MR, including the one just created. This mirrors the automatic
          # trigger, which reads the count before creating and adds one.
          def resolve_dependency_bump_iteration(merge_request)
            ::Ai::DuoWorkflows::Workflow
              .for_merge_request(merge_request)
              .with_workflow_definition(RESOLVE_DEPENDENCY_BUMP_WORKFLOW_DEFINITION)
              .count
          end

          def compute_server_capabilities(dws_capabilities:, namespace:)
            rails_capabilities = %w[job_trace_pagination tool_call_approval_source]
            rails_capabilities << "advanced_search" if advanced_search_enabled?

            if ::Ai::DuoWorkflows::Workflow.incremental_checkpoints_enabled_for?(namespace)
              rails_capabilities << "incremental_checkpoints"
            end

            # The instance keeps only the slim header and the blobs, so the gateway
            # can stop sending channel_values (see Workflow#write_incremental_only?).
            if ::Ai::DuoWorkflows::Workflow.write_incremental_only_enabled_for?(namespace)
              rails_capabilities << "incremental_checkpoints_only"
            end

            # Filter DWS capabilities based on admin/namespace/project settings
            unless tool_approval_for_session_enabled?(namespace)
              dws_capabilities.delete('tool_call_approval')
              dws_capabilities.delete('tool_call_pattern_approval')
            end

            (rails_capabilities + dws_capabilities).uniq
          end

          def tool_approval_for_session_enabled?(namespace)
            project = request_project_within(namespace)
            return project.project_setting.tool_approval_for_session_enabled? if project

            return false unless namespace

            !!namespace.namespace_settings&.tool_approval_for_session_enabled?
          end

          def serialize_channel_entries(channel, value)
            if value.is_a?(Array)
              value.map do |item|
                entry = item.is_a?(Hash) ? item.merge('channel' => channel) : { 'channel' => channel, 'value' => item }
                "#{Gitlab::Json.dump(entry)}\n"
              end
            elsif value.is_a?(Hash) && value.values.any? { |v| v.is_a?(Array) && v.any? }
              value.flat_map do |sub_key, sub_value|
                serialize_channel_entries("#{channel}.#{sub_key}", sub_value)
              end
            else
              ["#{Gitlab::Json.dump({ 'channel' => channel, 'value' => value })}\n"]
            end
          end

          # The full p_duo_workflows_checkpoints table is being retired
          # (gitlab-org/gitlab#605653); behind the read flag, source the trace's
          # channel_values from the slim header + incremental blobs so this path
          # stops reading that table.
          def trace_channel_values(workflow, thread, read, channels:)
            return blob_trace_channel_values(workflow, thread, channels: channels) if use_blob_read?(workflow, read)

            # The flag-off path reads the compacted latest checkpoint row, which
            # cannot span threads, so the thread filter has nothing to act on.
            latest = workflow.checkpoints.latest
            latest&.checkpoint&.dig('channel_values') || {}
          end

          # `read` is an undeclared internal override, removed with the read flag:
          # it forces the read path past the flag gate. 'incremental' reads the
          # header and blobs; 'legacy' reads the checkpoints table; any other value
          # (including nil) falls through to the default flag gate. 'incremental'
          # still requires incremental_checkpoints_enabled: a workflow that never
          # wrote blobs has nothing to reconstruct, so it falls back to the legacy
          # path instead of returning an empty trace.
          def use_blob_read?(workflow, read)
            case read
            when 'incremental' then workflow.incremental_checkpoints_enabled?
            when 'legacy' then false
            else read_trace_from_blobs?(workflow)
            end
          end

          # `thread`: absent -> full cross-thread trace (default); `latest` -> the
          # latest thread only; an integer -> that current_thread group only. A
          # value with no matching group (non-numeric, or numeric but out of the
          # current_thread column's int4 range) returns an empty trace instead of
          # querying, since the query itself would raise on an out-of-range integer.
          def blob_trace_channel_values(workflow, thread, channels:)
            case thread
            when nil, ''
              workflow.full_trace_channel_values(channels: channels)
            when 'latest'
              header = workflow.latest_checkpoint_header
              header ? workflow.reconstructed_channel_values(header, channels: channels) : {}
            else
              return {} unless thread.match?(/\A\d+\z/) && thread.to_i <= ::Gitlab::Database::MAX_INT_VALUE

              # Scoped to the top-level lineage, like #latest_checkpoint_header: a
              # nested subagent's header can share a current_thread id with the
              # workflow's own group, and only the workflow's own group is meant here.
              header = workflow.checkpoint_headers.for_checkpoint_ns(nil).for_current_thread(thread.to_i).last
              header ? workflow.reconstructed_channel_values(header, channels: channels) : {}
            end
          end

          # Per-consumer gate for the trace download: the general blob-read gate
          # (read FF plus the workflow's incremental_checkpoints_enabled column)
          # plus the trace-specific flag, so this consumer rolls out on its own.
          def read_trace_from_blobs?(workflow)
            return false unless workflow.reconstruct_from_blobs?

            Feature.enabled?(:dw_read_blobs_trace, workflow.resource_parent) ||
              Feature.enabled?(:dw_read_blobs_trace, workflow.resource_parent.root_ancestor)
          end

          def advanced_search_enabled?
            # advanced_search is a capability flag, not governance, so it uses the project directly.
            project = find_project(params[:project_id].presence)
            namespace_id = params[:root_namespace_id].presence ||
              params[:namespace_id].presence ||
              headers['X-Gitlab-Namespace-Id'].presence
            namespace = find_namespace(namespace_id)

            ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: project || namespace)
          end

          def duo_cli_request?
            headers['X-Gitlab-Client-Name'] == 'Duo CLI'
          end

          def duo_cli_disabled_by_admin?
            !::Ai::Setting.for_organization_read_only(::Current.organization).duo_cli_enabled
          end

          def audit_duo_cli_session_blocked
            audit_context = {
              name: 'duo_cli_session_blocked',
              author: current_user,
              scope: current_user,
              target: current_user,
              message: 'Duo CLI session was blocked because the administrator disabled Duo CLI'
            }

            ::Gitlab::Audit::Auditor.audit(audit_context)
          end

          params :workflow_params do
            optional :project_id, type: String, desc: 'The ID or path of the workflow project',
              documentation: { example: '1' }
            optional :namespace_id, type: String, desc: 'The ID or path of the workflow namespace',
              documentation: { example: '1' }
            optional :ai_catalog_item_consumer_id, type: Integer,
              desc: 'The ID of AI Catalog ItemConsumer that configures which catalog item to execute.',
              documentation: { example: 1 }
            optional :start_workflow, type: Boolean,
              desc: 'Optional parameter to start workflow in a CI pipeline.' \
                'This feature is currently in an experimental state.',
              documentation: { example: true }
            optional :goal, type: String, desc: 'Goal of the workflow',
              documentation: { example: 'Fix pipeline for merge request 1 in project 1' }
            optional :agent_privileges, type: [Integer], desc: 'The actions the agent is allowed to perform',
              documentation: { example: [1] }
            optional :pre_approved_agent_privileges, type: [Integer],
              desc: 'The actions the agent can perform without asking for approval',
              documentation: { example: [1] }
            optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
              documentation: { example: 'software_developer' }
            optional :allow_agent_to_request_user, type: Boolean,
              desc: 'When this is enabled Duo Agent Platform may stop to ask the user questions before proceeding. ' \
                'When it is disabled Duo Agent Platform will always just run through the workflow without ever ' \
                'asking for user input. Defaults to true.',
              documentation: { example: true }
            optional :image, type: String, desc: 'Container image to use for running the workflow in CI pipeline.',
              documentation: { example: 'registry.gitlab.com/gitlab-org/duo-workflow/custom-image:latest' }
            optional :source_branch, type: String,
              desc: 'Source branch for the CI pipeline. Uses default branch when not specified.',
              documentation: { example: 'main' }
            optional :environment, type: String,
              values: ::Ai::DuoWorkflows::Workflow.environments.keys.map(&:to_s),
              desc: 'Environment for the workflow.',
              documentation: { example: 'web' }
            optional :ai_catalog_item_version_id, type: Integer,
              desc: 'The ID of AI Catalog ItemVersion that sourced flow config used by the workflow.',
              documentation: { example: 1 }
            optional :additional_context, type: Array,
              desc: 'Additional Context required by the Flow, in JSON format. Contains an array of context details, ' \
                'where each detail is a Hash with a minimum of "Category" and "Content" keys.',
              documentation: {
                example: '[{"Category": "agent_user_environment", "Content": "{\"merge_request_url\": ' \
                  '\"https://gitlab.com/project/-/merge_requests/1\"}", "Metadata": "{}"}]'
              } do
                requires :Category, type: String, desc: 'The category of the context detail'
                requires :Content, type: String, desc: 'The content type of the context detail'
              end
            optional :shallow_clone, type: Boolean,
              desc: 'Whether or not the workflow should use a shallow clone of the repository during its execution.  ' \
                'Defaults to true.',
              default: true,
              documentation: { example: true }
            optional :issue_id, type: Integer,
              desc: 'IID of the Issue noteable that the workflow is associated with.',
              documentation: { example: 123 }
            optional :merge_request_id, type: Integer,
              desc: 'IID of the MergeRequest noteable that the workflow is associated with.',
              documentation: { example: 123 }
            optional :source, type: String, desc: 'Where the session was triggered from',
              values: WORKFLOW_ACTIONS_SOURCE,
              documentation: { example: 'merge_request_code_conflict' }
          end
        end

        namespace :ai do
          namespace :duo_workflows do
            resources :direct_access do
              desc 'Connection details for accessing Duo Agent Platform Service directly' do
                tags ['gitlab_duo_workflows']
                success code: 201
                failure [
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: 'Forbidden' },
                  { code: 404, message: 'Not found' },
                  { code: 429, message: 'Too many requests' }
                ]
              end

              params do
                optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
                  documentation: { example: 'software_developer' }
                optional :root_namespace_id, type: String, desc: 'the ID of the root namespace',
                  documentation: { example: '1' }
                optional :project_id, type: String, desc: 'The ID or path of the project',
                  documentation: { example: '1' }
              end

              route_setting :lifecycle, :experiment
              route_setting :authorization,
                permissions: :create_duo_workflow_direct_access_token,
                boundary_type: :user
              post do
                check_rate_limit!(:duo_workflow_direct_access, scope: current_user)

                root_namespace = find_root_namespace!

                quota_check_response = ::Ai::UsageQuotaService.new(
                  user: current_user,
                  namespace: root_namespace
                ).execute

                if quota_check_response.error?
                  message = case quota_check_response.reason
                            when :usage_quota_exceeded
                              "USAGE_QUOTA_EXCEEDED: #{quota_check_response.message}"
                            when :usage_billing_forbidden
                              "USAGE_BILLING_FORBIDDEN: #{quota_check_response.message}"
                            when :namespace_missing
                              ::Ai::FoundationalFlowMessages.namespace_missing_error(current_user)
                            else
                              quota_check_response.message
                            end

                  forbidden!(message)
                end

                oauth_token = gitlab_oauth_token
                governed_project = request_project_within(root_namespace)
                workflow_token = duo_workflow_token(container: governed_project || root_namespace)

                # Extract DWS capabilities from token response
                dws_capabilities = workflow_token[:capabilities] || []

                access = {
                  gitlab_rails: {
                    base_url: Gitlab.config.gitlab.url,
                    token: oauth_token.plaintext_token,
                    token_expires_at: oauth_token.expires_at
                  },
                  duo_workflow_service: {
                    base_url: Gitlab::DuoWorkflow::Client.url(user: current_user),
                    token: workflow_token[:token],
                    token_expires_at: workflow_token[:expires_at],
                    headers: Gitlab::AiGateway.public_headers(
                      user: current_user,
                      ai_feature_name: :duo_workflow,
                      unit_primitive_name: :duo_workflow_execute_workflow,
                      organization_id: get_current_organization_id,
                      namespace_id: find_most_specific_namespace&.id,
                      governing_namespace_id: root_namespace&.id
                    ).transform_keys(&:downcase),
                    secure: Gitlab::DuoWorkflow::Client.secure?(feature_setting: nil)
                  },
                  workflow_metadata: Gitlab::DuoWorkflow::Client.metadata(current_user,
                    namespace: find_request_namespace || root_namespace,
                    project: governed_project),
                  server_capabilities: compute_server_capabilities(
                    dws_capabilities: dws_capabilities,
                    namespace: most_specific_namespace_or_root(root_namespace)
                  )
                }

                present access, with: Grape::Presenters::Presenter
              end
            end

            resources :list_tools do
              desc 'List Duo Agent Platform tools' do
                tags ['gitlab_duo_workflows']
                success code: 200
                failure [
                  { code: 401, message: 'Unauthorized' },
                  { code: 404, message: 'Not found' },
                  { code: 429, message: 'Too many requests' }
                ]
              end

              params do
                optional :workflow_definition, type: String, desc: 'workflow type based on its capability',
                  documentation: { example: 'software_developer' }
              end

              route_setting :lifecycle, :experiment
              route_setting :authorization,
                permissions: :read_duo_workflow_tool,
                boundary_type: :user
              get do
                check_rate_limit!(:duo_workflow_direct_access, scope: current_user)

                result = duo_workflow_list_tools

                present(result.payload, with: Grape::Presenters::Presenter)
              end
            end

            desc 'Get Duo Workflows WebSocket connection details' do
              tags ['gitlab_duo_workflows']
              success code: 200
              failure [
                { code: 401, message: 'Unauthorized' },
                { code: 403, message: 'Forbidden' },
                { code: 404, message: 'Not found' }
              ]
            end
            params do
              optional :workflow_id, type: String,
                desc: 'The ID of an existing workflow. When provided and the workflow has a stored ' \
                  'model selection, that selection is reused to ensure provider stickiness.',
                documentation: { example: '1' }
            end
            route_setting :lifecycle, :experiment
            route_setting :authorization,
              permissions: :read_duo_workflow_websocket,
              boundary_type: :user
            get :ws do
              require_gitlab_workhorse!

              status :ok
              content_type Gitlab::Workhorse::INTERNAL_API_CONTENT_TYPE

              root_namespace = find_root_namespace!

              forbidden!("Missing default GitLab Duo namespace user preference") unless root_namespace

              most_specific_namespace = most_specific_namespace_or_root(root_namespace)

              push_feature_flags(root_namespace)

              feature_setting_name = find_feature_setting_name
              workflow = params[:workflow_id].present? &&
                ::Ai::DuoWorkflows::Workflow.for_user_with_id!(current_user.id, params[:workflow_id])

              model_metadata_headers =
                if Feature.enabled?(:duo_workflow_provider_stickiness, root_namespace) && workflow &&
                    workflow.model_metadata_json.present?
                  {
                    ::Gitlab::Llm::AiGateway::AgentPlatform::ModelMetadata::HEADER_KEY => workflow
                      .model_metadata_json
                  }
                else
                  ::Ai::DuoWorkflows::DuoAgentPlatformModelMetadataService.new(
                    root_namespace: root_namespace,
                    current_user: current_user,
                    user_selected_model_identifier: find_user_selected_model_identifier,
                    feature_name: feature_setting_name
                  ).execute
                end

              feature_setting = ::Ai::FeatureSettingSelectionService
                                  .new(
                                    current_user,
                                    feature_setting_name,
                                    root_namespace
                                  ).execute.payload

              ns_settings = most_specific_namespace.namespace_settings
              model_prompt_cache_enabled =
                ns_settings ? ns_settings.model_prompt_cache_enabled : root_namespace.model_prompt_cache_enabled

              workflow_context_service = workflow_context_generation_service
              gitlab_token = if workflow_context_service.already_scoped_for_ai_workflows?(access_token)
                               parsed_oauth_token
                             else
                               gitlab_oauth_token(workflow_context_service).plaintext_token
                             end

              mcp_config_service = ::Ai::DuoWorkflows::McpConfigService.new(
                current_user,
                gitlab_token,
                workflow_definition: params[:workflow_definition],
                ai_catalog_item_version_id: params[:ai_catalog_item_version_id]
              )

              project = request_project_within(root_namespace)

              tool_access_policies = if Feature.enabled?(:gitlab_duo_governance_settings, root_namespace)
                                       governance_surface = ::Ai::ToolRules::GovernanceSurface.for(
                                         environment: workflow.presence&.environment,
                                         container: root_namespace,
                                         workflow_definition: workflow.presence&.workflow_definition
                                       ) || :web

                                       result = ::Ai::ToolRules::ResolutionService.new(
                                         namespace: root_namespace,
                                         surface: governance_surface,
                                         project: project
                                       ).execute

                                       if result.success?
                                         { allow: result.payload[:pre_approved_tools] +
                                           mcp_config_service.preapproved_tool_names,
                                           deny: result.payload[:denied_tools] }
                                       else
                                         { allow: [], deny: [] }
                                       end
                                     else
                                       { allow: [], deny: [] }
                                     end

              cloud_connector_headers = Gitlab::DuoWorkflow::Client.cloud_connector_headers(
                user: current_user,
                project_id: params[:project_id],
                namespace_id: params[:namespace_id].presence&.to_i,
                governing_namespace_id: root_namespace.id,
                feature_setting: feature_setting,
                tool_access_policies: tool_access_policies,
                subject: (workflow && workflow.service_account) || current_user
              )

              client_type = params[:client_type].presence
              # client type from browser is sent as a query param in websocket request
              cloud_connector_headers['x-gitlab-client-type'] ||= client_type
              Gitlab::AiGateway.add_organization_header!(cloud_connector_headers, get_current_organization_id)

              grpc_headers = cloud_connector_headers.merge(
                'x-gitlab-oauth-token' => gitlab_token,
                'x-gitlab-unidirectional-streaming' => 'enabled',
                'x-gitlab-enabled-mcp-server-tools' => mcp_config_service.gitlab_enabled_tools.join(','),
                'x-gitlab-model-prompt-cache-enabled' => model_prompt_cache_enabled.to_s,
                'x-gitlab-self-hosted-dap-billing-enabled' =>
                  ::Ai::SelfHostedDapBilling.should_bill?(feature_setting).to_s,
                'x-gitlab-extended-logging' =>
                  ::Gitlab::DuoWorkflow::Client.enable_extended_logging?(current_user,
                    namespace: most_specific_namespace).to_s
              ).merge(model_metadata_headers)

              HEADERS_TO_FORWARD_AS_GRPC_METADATA.each do |header|
                header_value = headers[header]

                grpc_headers[header.downcase] = header_value if header_value.present?
              end

              {
                DuoWorkflow: {
                  Service: {
                    Headers: grpc_headers,
                    URI: Gitlab::DuoWorkflow::Client.url_for(feature_setting: feature_setting, user: current_user),
                    Secure: Gitlab::DuoWorkflow::Client.secure?(feature_setting: feature_setting)
                  },
                  CloudServiceForSelfHosted: cloud_service_for_self_hosted_config(feature_setting,
                    cloud_connector_headers),
                  McpServers: mcp_config_service.execute,
                  LockConcurrentFlow: client_type == 'browser' || Feature.disabled?(:lock_workflows_for_web_only,
                    current_user),
                  TimeoutHTTPRequests: Feature.enabled?(:timeout_dap_http_requests_in_workhorse, current_user),
                  CheckOriginByForwardedHost: (Gitlab::Saas.feature_available?(:gitlab_duo_saas_only) ||
                    Rails.env.development?) &&
                    Feature.enabled?(:duo_workflow_check_origin_by_forwarded_host, current_user),
                  # dws_capabilities is empty here because this endpoint does not fetch a DWS token.
                  # DWS-advertised capabilities flow through the workflow access path instead.
                  # See https://gitlab.com/gitlab-org/gitlab/-/work_items/592850 for a longer-term fix.
                  ServerCapabilities: compute_server_capabilities(
                    dws_capabilities: [],
                    namespace: most_specific_namespace
                  )
                }
              }
            end

            namespace :workflows do
              namespace ':workflow_id' do
                desc 'Get workflow trace as JSONL' do
                  detail 'Returns the full trace of a workflow session as JSON Lines (JSONL). ' \
                    'Each line is a JSON object representing one checkpoint event in chronological order.'
                  tags ['gitlab_duo_workflows']
                  success code: 200
                  failure [
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' }
                  ]
                end
                params do
                  requires :workflow_id, type: Integer, desc: 'The ID of the workflow',
                    documentation: { example: 1 }
                  optional :full, type: Boolean,
                    desc: 'Include internal channels (conversation history, handover, etc). ' \
                      'Restricted to the workflow owner; non-owners receive a 403.',
                    documentation: { example: false }
                  optional :thread, type: String,
                    desc: 'Which thread to return: omit for the full cross-thread trace (default), ' \
                      "'latest' for the latest thread only, or a current_thread id for that thread only. " \
                      'Only applies on the blob-read path.',
                    documentation: { example: 'latest' }
                  # `read` is an internal override read straight from params (see
                  # use_blob_read?). It is intentionally not declared here, so it
                  # stays out of the published API docs and no consumer depends on
                  # it before the read flag removes it (gitlab-org/gitlab#605653).
                end
                route_setting :lifecycle, :experiment
                route_setting :authorization,
                  permissions: :read_duo_workflow,
                  boundary_type: :user
                get 'trace.jsonl' do
                  full = params[:full].present?

                  workflow = if full
                               # for_user_with_id! scopes to current_user; a non-owner
                               # requesting full=true gets 404, mirroring the legacy behavior.
                               find_workflow!(params[:workflow_id])
                             else
                               found = ::Ai::DuoWorkflows::Workflow.find_by_id(params[:workflow_id])
                               not_found!('Workflow') unless found
                               authorize!(:read_duo_workflow, found)
                               found
                             end

                  content_type 'application/x-ndjson'
                  env['api.format'] = :binary

                  lines = []

                  if workflow.goal.present?
                    lines << "#{Gitlab::Json.dump({ 'channel' => 'goal', 'value' => workflow.goal })}\n"
                  end

                  # channels: nil on the blob-read path fetches and decodes only the
                  # safe set up front for full: false, instead of loading every
                  # channel's full history and discarding the internal ones below.
                  channels = full ? nil : TRACE_SAFE_CHANNELS
                  channel_values = trace_channel_values(workflow, params[:thread], params[:read], channels: channels)
                  channel_values = channel_values.slice(*TRACE_SAFE_CHANNELS) unless full
                  lines += channel_values.flat_map { |channel, value| serialize_channel_entries(channel, value) }

                  body = lines.join
                  if body.bytesize > TRACE_MAX_RESPONSE_BYTESIZE
                    file_too_large!('Workflow trace exceeds maximum allowed size')
                  end

                  body
                end
              end

              desc 'Create a flow' do
                detail 'Creates and starts a flow.'
                tags ['gitlab_duo_workflows']
                success code: 200
                failure [
                  { code: 400, message: 'Validation failed' },
                  { code: 401, message: 'Unauthorized' },
                  { code: 403, message: '403 Forbidden' },
                  { code: 404, message: 'Not found' }
                ]
              end
              params do
                use :workflow_params
              end
              route_setting :lifecycle, :experiment
              route_setting :authorization,
                permissions: :create_duo_workflow,
                boundary_type: :user
              post do
                if duo_cli_request? && duo_cli_disabled_by_admin?
                  audit_duo_cli_session_blocked
                  forbidden!('Duo CLI has been disabled by your administrator')
                end

                ::Gitlab::QueryLimiting.disable!(
                  'https://gitlab.com/gitlab-org/gitlab/-/issues/566195', new_threshold: 125
                )

                container = if params[:project_id]
                              find_project!(params[:project_id])
                            elsif params[:namespace_id]
                              find_namespace!(params[:namespace_id])
                            else
                              current_user.default_duo_namespace
                            end

                if container.nil?
                  bad_request!('No default namespace found. Please provide project_id or namespace_id, ' \
                    'or configure a default Duo namespace.')
                end

                forbidden!('Access to the container is not allowed') unless container_access_allowed?(container)

                if params[:ai_catalog_item_consumer_id]
                  unless container.is_a?(Project)
                    bad_request!('AI Catalog flows can only be executed in project context')
                  end

                  consumer = find_item_consumer!(params[:ai_catalog_item_consumer_id], container)

                  service_account = if consumer.project.present?
                                      consumer.parent_item_consumer&.service_account
                                    else
                                      consumer.service_account
                                    end

                  flow_params = {
                    item_consumer: consumer,
                    service_account: service_account,
                    execute_workflow: params[:start_workflow].present?,
                    event_type: 'api_execution',
                    user_prompt: params[:goal],
                    source_branch: params[:source_branch],
                    additional_context: build_additional_context(consumer, params[:additional_context]),
                    issue_id: params[:issue_id],
                    merge_request_id: params[:merge_request_id]
                  }

                  result = ::Ai::Catalog::Flows::ExecuteService.new(
                    project: container,
                    current_user: current_user,
                    params: flow_params
                  ).execute

                  bad_request!(result.message) if result.error?

                  workflow = result.payload[:workflow]
                  workload_id = result.payload[:workload_id]

                  link_vulnerability_to_user_triggered_workflow(workflow)

                  track_event(consumer: consumer, workflow: workflow)

                  present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                    workload: { id: workload_id, message: result.message }
                else
                  workflow_params = create_workflow_params

                  execution = authorize_flow_execution!(
                    workflow_params, container,
                    caller_can_execute: true,
                    start_workflow: params[:start_workflow].present?,
                    item_consumer_id: params[:ai_catalog_item_consumer_id]
                  )

                  service = ::Ai::DuoWorkflows::CreateWorkflowService.new(
                    container: container, current_user: current_user, params: workflow_params,
                    execution: execution)

                  result = service.execute

                  forbidden!(result.message) if result.error? && result.http_status == :forbidden
                  not_found!(result.message) if result.error? && result.http_status == :not_found
                  if result.error? && result.http_status == :payment_required
                    forbidden!("session failed to start due to insufficient GitLab credits. " \
                      "Purchase more credits to continue.")
                  end

                  bad_request!(result[:message]) if result[:status] == :error

                  link_vulnerability_to_user_triggered_workflow(result[:workflow])

                  push_ai_gateway_headers(scope: container,
                    subject: workflow_params[:service_account] || current_user)

                  if params[:start_workflow].present?
                    response = ::Ai::DuoWorkflows::StartWorkflowService.new(
                      workflow: result[:workflow],
                      params: start_workflow_params(result[:workflow].id, container: container,
                        service_account: workflow_params[:service_account])
                    ).execute

                    if response.error?
                      status_code = case response.reason
                                    when :unprocessable_entity
                                      :unprocessable_entity
                                    when :feature_unavailable, :invalid_service_account
                                      :forbidden
                                    when :workload_failure
                                      :unprocessable_entity
                                    else
                                      :internal_server_error
                                    end
                      render_api_error!(response.message, status_code)
                    else
                      workload_id = response.payload && response.payload[:workload_id]
                      message = response.message

                      track_event
                    end
                  end

                  present result[:workflow], with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                    workload: { id: workload_id, message: message }
                end
              end

              desc 'List all agent privileges' do
                detail 'Lists all available agent privileges with their IDs, names, descriptions, and whether each ' \
                  'is enabled by default. This endpoint has no supported attributes.'
                tags ['gitlab_duo_workflows']
                success code: 200
                failure [
                  { code: 401, message: 'Unauthorized' }
                ]
              end
              route_setting :authorization,
                permissions: :read_duo_workflow_agent_privilege,
                boundary_type: :user
              get 'agent_privileges' do
                present ::Ai::DuoWorkflows::Workflow::AgentPrivileges,
                  with: ::API::Entities::Ai::DuoWorkflows::Workflow::AgentPrivileges
              end

              params do
                requires :workflow_id, type: String, desc: 'The ID of the workflow'
              end
              namespace ':workflow_id' do
                desc 'Resume a paused workflow' do
                  tags ['gitlab_duo_workflows']
                  success code: 201
                  failure [
                    { code: 400, message: 'Validation failed' },
                    { code: 401, message: 'Unauthorized' },
                    { code: 403, message: 'Forbidden' },
                    { code: 404, message: 'Not found' },
                    { code: 422, message: 'Unprocessable entity' }
                  ]
                end
                params do
                  requires :workflow_id, type: String, desc: 'The ID of the workflow to resume',
                    documentation: { example: '1' }
                  requires :human_approval, type: Boolean,
                    desc: 'Whether the human approves resuming the workflow',
                    documentation: { example: true }
                  optional :human_message, type: String,
                    desc: 'Optional message accompanying the human decision',
                    documentation: { example: 'Looks good, please proceed' },
                    limit: 2000
                end
                route_setting :authorization, permissions: :resume_duo_workflow, boundary_type: :user
                post :resume do
                  workflow = find_workflow!(params[:workflow_id])
                  authorize!(:resume_duo_workflow, workflow)

                  container = workflow.project || workflow.namespace

                  push_ai_gateway_headers(scope: container,
                    subject: workflow.service_account || current_user)
                  consumer = find_catalog_consumer_for_workflow!(workflow)

                  service_account = if consumer.project.present?
                                      consumer.parent_item_consumer&.service_account
                                    else
                                      consumer.service_account
                                    end

                  flow_params = {
                    item_consumer: consumer,
                    service_account: service_account,
                    execute_workflow: true,
                    event_type: 'api_execution',
                    user_prompt: workflow.goal,
                    resume_context: {
                      existing_workflow: workflow,
                      human_approval: params[:human_approval],
                      human_message: params[:human_message]
                    }
                  }

                  result = ::Ai::Catalog::Flows::ExecuteService.new(
                    project: container,
                    current_user: current_user,
                    params: flow_params
                  ).execute

                  bad_request!(result.message) if result.error?

                  workload_id = result.payload[:workload_id]
                  message = result.message

                  present workflow, with: ::API::Entities::Ai::DuoWorkflows::Workflow,
                    workload: { id: workload_id, message: message }
                end
              end
            end
          end
        end
      end
    end
  end
end
