# frozen_string_literal: true

module Types
  module Ai
    module DuoWorkflows
      class WorkflowType < Types::BaseObject
        graphql_name 'DuoWorkflow'
        description 'GitLab Duo Agent Platform session'
        implements Types::TodoableInterface
        present_using ::Ai::DuoWorkflows::WorkflowPresenter
        authorize :read_duo_workflow

        FIELD_SCOPES = [:api, :read_api, :ai_features, :ai_workflows].freeze

        def self.authorization_scopes
          FIELD_SCOPES
        end

        field :id, type: GraphQL::Types::ID,
          scopes: FIELD_SCOPES,
          null: false, description: 'ID of the session.'

        # The user id will always be the current_user.id as
        # only workflow owners can read a workflow
        field :user_id, Types::GlobalIDType[User],
          scopes: FIELD_SCOPES,
          null: false, description: 'ID of the user.'

        field :user, ::Types::UserType,
          scopes: FIELD_SCOPES,
          null: true, description: 'User who created the session.'

        field :project_id, Types::GlobalIDType[Project],
          scopes: FIELD_SCOPES,
          null: true, description: 'ID of the project.'

        field :project, Types::ProjectType,
          scopes: FIELD_SCOPES,
          null: true, description: "Project that the session is in."

        field :namespace_id, Types::GlobalIDType[Namespace],
          scopes: FIELD_SCOPES,
          null: true, description: 'ID of the namespace.'

        field :namespace, Types::NamespaceType,
          scopes: FIELD_SCOPES,
          null: true, description: "namespace that the session is in."

        field :human_status, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: false, description: 'Human-readable status of the session.'

        field :created_at, Types::TimeType,
          scopes: FIELD_SCOPES,
          null: false, description: 'Timestamp of when the session was created.'

        field :updated_at, Types::TimeType,
          scopes: FIELD_SCOPES,
          null: false, description: 'Timestamp of when the session was last updated.'

        field :goal, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          description: 'Goal of the session.'

        field :workflow_definition, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          description: 'GitLab Duo Agent Platform flow type based on its capabilities.'

        field :environment, Types::Ai::DuoWorkflows::WorkflowEnvironmentEnum,
          scopes: FIELD_SCOPES,
          description: 'Environment, like IDE or web.'

        field :agent_privileges_names, [GraphQL::Types::String],
          scopes: FIELD_SCOPES,
          description: 'Privileges granted to the agent during execution.'

        field :pre_approved_agent_privileges_names, [GraphQL::Types::String],
          scopes: FIELD_SCOPES,
          description: 'Privileges pre-approved for the agent during execution.'

        # rubocop:disable Graphql/JSONType -- There is infinite number of possible keys representing tool names in this object
        field :tool_call_approvals, GraphQL::Types::JSON,
          scopes: FIELD_SCOPES,
          description: 'Tools approval per session policy.'
        # rubocop:enable Graphql/JSONType

        field :tool_call_approved, GraphQL::Types::Boolean,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false,
          description: 'Whether the specified tool call is approved for the session.' do
          argument :tool_call_args, GraphQL::Types::String,
            required: true,
            description: 'JSON-serialized arguments for the tool call.',
            validates: { length: { maximum: 64.kilobytes } }
          argument :tool_name, GraphQL::Types::String,
            required: true,
            description: 'Name of the tool to check.'
        end

        field :external_mcp_blocked, GraphQL::Types::Boolean,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false,
          description: "Whether the workflow's external MCP server tools are currently blocked for " \
            'the namespace (group-level kill-switch). Checked per tool call so blocking takes ' \
            'effect mid-session.',
          experiment: { milestone: '19.3' }

        field :tool_call_approval_match, Types::Ai::DuoWorkflows::ToolCallApprovalMatchType, # rubocop:disable GraphQL/ExtractType -- tool_call fields are integral to workflow
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: false,
          description: 'Approval match details for the specified tool call.',
          experiment: { milestone: '19.3' } do
          argument :tool_call_args, GraphQL::Types::String,
            required: true,
            description: 'JSON-serialized arguments for the tool call.',
            validates: { length: { maximum: 64.kilobytes } }
          argument :tool_name, GraphQL::Types::String,
            required: true,
            description: 'Name of the tool to check.'
        end

        field :mcp_enabled, GraphQL::Types::Boolean,
          scopes: FIELD_SCOPES,
          description: 'Has MCP been enabled for the namespace.'

        field :incremental_checkpoints_enabled, GraphQL::Types::Boolean,
          scopes: FIELD_SCOPES,
          description: 'Indicates incremental checkpoints were enabled for the session at creation.'

        field :web_url, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: true,
          description: 'URL of the session.'

        field :web_search_enabled, GraphQL::Types::Boolean, # rubocop:disable GraphQL/ExtractType -- Session URL and web search state are unrelated.
          scopes: FIELD_SCOPES,
          description: 'Whether web search is enabled for the session.',
          experiment: { milestone: '19.3' }

        field :allow_agent_to_request_user, GraphQL::Types::Boolean,
          scopes: FIELD_SCOPES,
          description: 'Allow the agent to request user input.'

        field :status, Types::Ai::DuoWorkflows::WorkflowStatusEnum,
          scopes: FIELD_SCOPES,
          description: 'Status of the session.'

        field :status_name, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          description: 'Status name of the session.'

        field :status_group, Types::Ai::DuoWorkflows::WorkflowStatusGroupEnum, # rubocop: disable GraphQL/ExtractType -- does not make sense
          scopes: FIELD_SCOPES,
          description: 'Status group of the flow session.'

        field :first_checkpoint, Types::Ai::DuoWorkflows::WorkflowEventType,
          scopes: FIELD_SCOPES,
          description: "First checkpoint of the session." do
          argument :checkpoint_ns, GraphQL::Types::String,
            required: false,
            experiment: { milestone: '19.3' },
            description: 'LangGraph checkpoint namespace to scope the lookup to. ' \
              'Omit (or pass an empty string) for the session\'s own top-level checkpoint lineage; ' \
              'used internally to resolve one nested subgraph invocation, e.g. a delegated subagent.'
        end

        field :latest_checkpoint, Types::Ai::DuoWorkflows::WorkflowEventType,
          scopes: FIELD_SCOPES,
          description: "Latest checkpoint of the session." do
          argument :checkpoint_ns, GraphQL::Types::String,
            required: false,
            experiment: { milestone: '19.3' },
            description: 'LangGraph checkpoint namespace to scope the lookup to. ' \
              'Omit (or pass an empty string) for the session\'s own top-level checkpoint lineage; ' \
              'used internally to resolve one nested subgraph invocation, e.g. a delegated subagent.'
        end

        field :summary, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          description: 'Summary of the session.'

        field :title, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          description: 'Title of the session.'

        field :archived, GraphQL::Types::Boolean, method: :archived?,
          scopes: FIELD_SCOPES,
          description: 'Archived due to retention policy.'

        field :stalled, GraphQL::Types::Boolean, method: :stalled?,
          scopes: FIELD_SCOPES,
          description: 'Workflow got created but has no checkpoints.'

        field :last_executor_logs_url, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          description: "URL to the latest executor logs of the workflow."

        field :all_executor_logs_urls, [GraphQL::Types::String],
          scopes: FIELD_SCOPES,
          description: "List of all the executor logs for the workflow."

        field :ai_catalog_item_version_id, Types::GlobalIDType[::Ai::Catalog::ItemVersion],
          scopes: FIELD_SCOPES,
          null: true, description: 'ID of the AI catalog item version that triggered the workflow.',
          experiment: { milestone: '18.4' }

        # rubocop:disable GraphQL/ExtractType -- no value for now
        field :resource_iid, GraphQL::Types::Int,
          scopes: FIELD_SCOPES,
          null: true, description: 'IID of the associated resource (issue or merge request).'

        field :resource_web_url, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: true, description: 'Web URL of the associated resource (issue or merge request).'

        field :work_item, Types::WorkItemType,
          scopes: FIELD_SCOPES,
          null: true, description: 'Associated work item (issue or epic), if any.'

        field :merge_request, Types::MergeRequestType,
          scopes: FIELD_SCOPES,
          null: true, description: 'Associated merge request, if any.'
        # rubocop:enable GraphQL/ExtractType

        # rubocop:disable GraphQL/ExtractType -- links are a distinct connection with their own filter, not a sub-object of work_item
        field :work_item_links,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkflowWorkItemLinksResolver,
          scopes: FIELD_SCOPES,
          description: 'Work items linked to the session.'
        # rubocop:enable GraphQL/ExtractType

        # rubocop:disable GraphQL/ExtractType -- links are a distinct connection with their own filter, not a sub-object of merge_request
        field :merge_request_links,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkflowMergeRequestLinksResolver,
          scopes: FIELD_SCOPES,
          description: 'Merge requests linked to the session.'
        # rubocop:enable GraphQL/ExtractType

        field :note_links,
          resolver: ::Resolvers::Ai::DuoWorkflows::WorkflowNoteLinksResolver,
          scopes: FIELD_SCOPES,
          description: 'Notes linked to the session.'

        field :agent_name, GraphQL::Types::String, # rubocop: disable GraphQL/ExtractType -- keeping agent fields flat for simpler API
          scopes: FIELD_SCOPES,
          null: true, description: 'Name of the agent used for the workflow.',
          experiment: { milestone: '18.8' }

        # rubocop:disable GraphQL/ExtractType -- model metadata fields are intentionally kept flat for a consistent session-detail API
        field :model_metadata_name, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: true, description: 'Model used for the session.',
          experiment: { milestone: '19.2' }

        field :model_metadata_identifier, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: true,
          description: 'Provider model identifier used for the session.',
          experiment: { milestone: '19.2' }
        # rubocop:enable GraphQL/ExtractType

        # rubocop:disable GraphQL/ExtractType -- flow_metadata fields are intentionally kept flat for a consistent session-detail API
        field :flow_metadata_version, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: true,
          description: 'Version of the flow that was executed in the session.',
          experiment: { milestone: '19.3' }

        field :flow_metadata_id, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: true,
          description: 'Identifier of the flow that was executed in the session.',
          experiment: { milestone: '19.3' }

        field :flow_metadata_schema_version, GraphQL::Types::String,
          scopes: FIELD_SCOPES,
          null: true,
          description: 'Schema version of the flow metadata for the session.',
          experiment: { milestone: '19.3' }
        # rubocop:enable GraphQL/ExtractType

        field :user_permissions, Types::PermissionTypes::Ai::DuoWorkflows::Workflow, # rubocop: disable GraphQL/ExtractType -- user_id is intentionally separate as per comment above
          scopes: FIELD_SCOPES,
          null: true,
          description: 'Permissions of the current user for the workflow.',
          method: :itself

        field :audit_events, ::Types::AuditEvents::AiAuditEventType.connection_type,
          scopes: [:api, :read_api, :ai_features, :ai_workflows],
          null: true,
          authorize: :read_agent_artifacts,
          description: 'Audit events recorded for the session. ' \
            'Requires `read_agent_artifacts` on the workflow\'s project or namespace. ' \
            'Returns no events when the `agent_artifacts_page` feature flag is disabled.',
          experiment: { milestone: '19.0' }

        def audit_events
          return ::AuditEvents::AiAuditEvent.none unless agent_artifacts_page_enabled?

          ::AuditEvents::AiAuditEvents::Finder.new(workflow: object).execute
        end

        def tool_call_approved(tool_name:, tool_call_args:)
          tool_call_approvals_object.approved?(tool_name: tool_name, call_args: tool_call_args)
        end

        # Per-call kill-switch and the SINGLE source of truth for MCP server blocking. The gateway
        # queries this live before every external MCP tool call (McpTool._execute), so a block takes
        # effect mid-session without relying on session-start state. Resolves against the workflow's
        # own namespace ancestry, so it is request-independent and consistent for new and in-flight
        # sessions. Coarse "any attached server is blocked" - exact for single-external-server agents
        # (precise tool->server mapping is a follow-up).
        def external_mcp_blocked
          return false unless ::Feature.enabled?(:mcp_server_block_enforcement, root_namespace)

          namespace = enforcement_namespace
          return false unless namespace

          server_ids = Array(object.ai_catalog_item_version&.def_mcp_servers)
          return false if server_ids.empty?

          batch_external_mcp_blocked(namespace, server_ids)
        end

        def tool_call_approval_match(tool_name:, tool_call_args:)
          tool_call_approvals_object.approval_match(tool_name: tool_name, call_args: tool_call_args)
        end

        private

        def tool_call_approvals_object
          @tool_call_approvals_object ||= ::Ai::DuoWorkflows::Workflow::ToolCallApprovals.new(
            object.tool_call_approvals || {}
          )
        end

        # Batched so a list of workflows resolves the kill-switch with a single blocks lookup instead
        # of one query per workflow. `self_and_ancestor_ids` is traversal_ids (in-memory), so only the
        # blocks lookup touches the database.
        def batch_external_mcp_blocked(namespace, server_ids)
          ::BatchLoader::GraphQL.for([namespace, server_ids]).batch(default_value: false) do |keys, loader|
            namespace_ids = keys.flat_map { |ns, _| ns.self_and_ancestor_ids }.uniq
            all_server_ids = keys.flat_map { |_, ids| ids }.uniq

            blocked_pairs = ::Ai::Catalog::McpServerBlock
              .blocked_namespace_server_pairs(namespace_ids, all_server_ids)
              .to_set

            keys.each do |ns, ids|
              ancestor_ids = ns.self_and_ancestor_ids
              blocked = ids.any? { |sid| ancestor_ids.any? { |aid| blocked_pairs.include?([aid, sid]) } }
              loader.call([ns, ids], blocked)
            end
          end
        end

        def agent_artifacts_page_enabled?
          ::Feature.enabled?(:agent_artifacts_page, root_namespace)
        end

        def root_namespace
          (object.project || object.namespace)&.root_ancestor
        end

        # The most-specific namespace the workflow runs in, so a project-level block (stored against
        # the project-namespace) is enforced as well as group/ancestor blocks. Enforcement walks
        # this namespace's ancestry (`self_and_ancestor_ids`).
        def enforcement_namespace
          object.project&.project_namespace || object.namespace
        end
      end
    end
  end
end
