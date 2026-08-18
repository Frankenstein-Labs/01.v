# frozen_string_literal: true

module Ai
  # Computes the list of capabilities the instance advertises for Duo Agent
  # Platform flows (for example: checkpoint pagination, advanced search, or
  # the default flow a new Duo CLI session should run).
  #
  # This intentionally mirrors a subset of the `server_capabilities` computed
  # by the REST `direct_access` endpoint
  # (ee/lib/api/ai/duo_workflows/workflows.rb#compute_server_capabilities) and
  # is meant to eventually replace it. Capabilities Rails can compute locally
  # are combined with capabilities that require a live round trip to the Duo
  # Workflow Service (via `ListCapabilities`), such as `tool_call_approval`.
  class FlowsMetadataService
    # DWS advertises these regardless of whether the caller's namespace/project
    # has opted in to per-session tool approval; filter them out here to
    # mirror `Api::Ai::DuoWorkflows::Workflows#tool_approval_for_session_enabled?`.
    TOOL_APPROVAL_CAPABILITIES = %w[tool_call_approval tool_call_pattern_approval].freeze

    # DWS capabilities are effectively static per Duo Workflow Service
    # deployment, so caching them avoids a gRPC round trip on every
    # `aiFlowsMetadata` request.
    DWS_CAPABILITIES_CACHE_KEY = 'ai_flows_metadata:dws_capabilities'
    DWS_CAPABILITIES_CACHE_EXPIRATION = 1.hour

    # @param current_user [User, nil]
    # @param namespace [Namespace, nil] a group or personal namespace to scope
    #   capabilities to. Ignored (falls back to instance-wide) when `project`
    #   is also given.
    # @param project [Project, nil] a project to scope capabilities to. Takes
    #   precedence over `namespace` when both are given, mirroring the REST
    #   `direct_access` endpoint's `project || namespace` precedence.
    def initialize(current_user:, namespace: nil, project: nil)
      @current_user = current_user
      @namespace = namespace
      @project = project
    end

    def execute
      [
        { name: 'job_trace_pagination', metadata: nil },
        { name: 'tool_call_approval_source', metadata: nil },
        advanced_search_capability,
        incremental_checkpoints_capability,
        incremental_checkpoints_only_capability,
        duo_developer_capability,
        *dws_capabilities
      ].compact
    end

    private

    attr_reader :current_user, :namespace, :project

    def advanced_search_capability
      return unless ::Gitlab::CurrentSettings.search_using_elasticsearch?(scope: project || namespace)

      { name: 'advanced_search', metadata: nil }
    end

    def incremental_checkpoints_capability
      return unless ::Ai::DuoWorkflows::Workflow.incremental_checkpoints_enabled_for?(namespace)

      { name: 'incremental_checkpoints', metadata: nil }
    end

    # The instance keeps only the slim header and the blobs, so the gateway can
    # stop sending channel_values (see Workflow#write_incremental_only?).
    def incremental_checkpoints_only_capability
      return unless ::Ai::DuoWorkflows::Workflow.write_incremental_only_enabled_for?(namespace)

      { name: 'incremental_checkpoints_only', metadata: nil }
    end

    # Advertises the "default flow" the Duo CLI should run when the
    # `duo_cli_default_flow` feature flag is enabled, with `metadata`
    # carrying the registry coordinates so the client never hardcodes a
    # flow version.
    #
    # TODO: `flow_config_id`/`flow_config_schema_version`/`flow_version`
    # are hardcoded below because there is no shared source of truth for
    # them yet. Extract them into a shared constant/registry:
    # https://gitlab.com/gitlab-org/gitlab/-/work_items/605476
    def duo_developer_capability
      return unless current_user
      return unless Feature.enabled?(:duo_cli_default_flow, current_user)

      {
        name: 'duo_developer',
        metadata: {
          flow_config_id: 'developer',
          flow_config_schema_version: 'v1',
          flow_version: '2.0.0-interactive'
        }
      }
    end

    # Fetches capabilities that only the Duo Workflow Service knows about
    # (for example `tool_call_approval`). Fails open: any error talking to
    # DWS results in an empty list rather than failing the whole query.
    def dws_capabilities
      return [] unless current_user

      capabilities = cached_dws_capabilities

      return capabilities if tool_approval_for_session_enabled?

      capabilities.reject { |capability| TOOL_APPROVAL_CAPABILITIES.include?(capability[:name]) }
    end

    # Only successful responses are cached, so a transient DWS outage is
    # retried on the next request instead of being remembered as "no
    # capabilities" for the remainder of the cache TTL.
    def cached_dws_capabilities
      Rails.cache.read(DWS_CAPABILITIES_CACHE_KEY) || fetch_and_cache_dws_capabilities
    end

    def fetch_and_cache_dws_capabilities
      response = duo_workflow_service_client.list_capabilities

      unless response.success?
        Gitlab::AppLogger.error("FlowsMetadataService ListCapabilities failed: #{response.message}")
        return []
      end

      capabilities = response.payload[:capabilities]
      Rails.cache.write(DWS_CAPABILITIES_CACHE_KEY, capabilities, expires_in: DWS_CAPABILITIES_CACHE_EXPIRATION)
      capabilities
    rescue StandardError => e
      Gitlab::AppLogger.error("FlowsMetadataService ListCapabilities failed: #{e.message}")
      []
    end

    def duo_workflow_service_client
      feature_setting = resolve_feature_setting

      ::Ai::DuoWorkflow::DuoWorkflowService::Client.new(
        duo_workflow_service_url: ::Gitlab::DuoWorkflow::Client.url_for(
          feature_setting: feature_setting, user: current_user
        ),
        current_user: current_user,
        secure: ::Gitlab::DuoWorkflow::Client.secure?(feature_setting: feature_setting)
      )
    end

    def resolve_feature_setting
      root_namespace = (project || namespace)&.root_ancestor
      return unless root_namespace

      ::Ai::FeatureSettingSelectionService.new(
        current_user,
        ::Ai::ModelSelection::FeaturesConfigurable.workflow_feature_name,
        root_namespace
      ).execute.payload
    end

    def tool_approval_for_session_enabled?
      return !!project.project_setting.tool_approval_for_session_enabled? if project
      return false unless namespace

      !!namespace.namespace_settings&.tool_approval_for_session_enabled?
    end
  end
end
