# frozen_string_literal: true

RSpec.shared_context 'with remote development shared fixtures' do
  include RemoteDevelopment::FixtureFileHelpers

  include_context "with constant modules"

  # rubocop:todo Metrics/ParameterLists, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity -- Cleanup as part of https://gitlab.com/gitlab-org/gitlab/-/issues/421687

  # @return [String]
  def create_desired_config_json
    RemoteDevelopment::FixtureFileHelpers.read_fixture_file('example.desired_config.json')
  end

  # @return [Array<Hash>]
  def create_desired_config_array
    Gitlab::Json.safe_parse(create_desired_config_json).map(&:deep_symbolize_keys)
  end

  # @param [RemoteDevelopment::Workspace] workspace
  # @param [String] previous_actual_state
  # @param [String] current_actual_state
  # @param [Boolean] workspace_exists
  # @param [Hash] workspace_variables_environment
  # @param [Hash] workspace_variables_file
  # @param [Hash] workspace_variables_additional_data
  # @param [String] resource_version
  # @param [String] dns_zone
  # @param [Hash] error_details
  # @return [Hash]
  def create_workspace_agent_info_hash(
    workspace:,
    # NOTE: previous_actual_state is the actual state of the workspace IMMEDIATELY prior to the current state. We don't
    # simulate the situation where there may have been multiple transitions between reconciliation polling intervals.
    previous_actual_state:,
    current_actual_state:,
    # NOTE: workspace_exists is whether the workspace exists in the cluster at the time of the current_actual_state.
    workspace_exists:,
    workspace_variables_environment: nil,
    workspace_variables_file: nil,
    workspace_variables_additional_data: nil,
    resource_version: '1',
    dns_zone: 'workspaces.localdev.me',
    error_details: nil
  )
    info = {
      name: workspace.name,
      namespace: workspace.namespace
    }

    if current_actual_state == states_module::TERMINATED
      info[:termination_progress] =
        states_module::TERMINATED
    end

    if current_actual_state == states_module::TERMINATING
      info[:termination_progress] =
        states_module::TERMINATING
    end

    if [
      states_module::TERMINATING,
      states_module::TERMINATED,
      states_module::UNKNOWN
    ].include?(current_actual_state)
      return info
    end

    # rubocop:disable Layout/LineLength -- Keep the individual 'in' cases on single lines for readability
    spec_replicas =
      if [states_module::STOPPED, states_module::STOPPING]
           .include?(current_actual_state)
        0
      else
        1
      end

    started = spec_replicas == 1

    # rubocop:todo Lint/DuplicateBranch -- Make this cop recognize that different arrays with different entries are not duplicates
    status =
      case [previous_actual_state, current_actual_state, workspace_exists]
      in [RemoteDevelopment::WorkspaceOperations::States::CREATION_REQUESTED, RemoteDevelopment::WorkspaceOperations::States::STARTING, _]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:14:14Z"
            lastUpdateTime: "2023-04-10T10:14:14Z"
            message: Created new replica set "#{workspace.name}-hash"
            reason: NewReplicaSetCreated
            status: "True"
            type: Progressing
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::STARTING, false]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:14:14Z"
            lastUpdateTime: "2023-04-10T10:14:14Z"
            message: Deployment does not have minimum availability.
            reason: MinimumReplicasUnavailable
            status: "False"
            type: Available
          - lastTransitionTime: "2023-04-10T10:14:14Z"
            lastUpdateTime: "2023-04-10T10:14:14Z"
            message: ReplicaSet "#{workspace.name}-hash" is progressing.
            reason: ReplicaSetUpdated
            status: "True"
            type: Progressing
          observedGeneration: 1
          replicas: 1
          unavailableReplicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::RUNNING, false]
        <<~'YAML'
          availableReplicas: 1
          conditions:
          - lastTransitionTime: "2023-03-06T14:36:36Z"
            lastUpdateTime: "2023-03-06T14:36:36Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-03-06T14:36:31Z"
            lastUpdateTime: "2023-03-06T14:36:36Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          readyReplicas: 1
          replicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::FAILED, false]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STARTING, false]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::RUNNING, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::RUNNING, RemoteDevelopment::WorkspaceOperations::States::STOPPING, _]
        <<~'YAML'
          availableReplicas: 1
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:35Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          observedGeneration: 1
          readyReplicas: 1
          replicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPING, RemoteDevelopment::WorkspaceOperations::States::STOPPED, _]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:35Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          observedGeneration: 2
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::STOPPED, true]
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          - lastTransitionTime: "2023-04-10T10:49:59Z"
            lastUpdateTime: "2023-04-10T10:49:59Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          observedGeneration: 2
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPING, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::STARTING, _]
        # There are multiple state transitions inside kubernetes
        # Fields like `replicas`, `unavailableReplicas` and `updatedReplicas` eventually become present
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          - lastTransitionTime: "2023-04-10T10:49:59Z"
            lastUpdateTime: "2023-04-10T10:49:59Z"
            message: Deployment does not have minimum availability.
            reason: MinimumReplicasUnavailable
            status: "False"
            type: Available
          observedGeneration: 3
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STOPPED, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        # Stopped workspace is terminated by the user which results in a Failed actual state.
        # e.g. could not unmount volume and terminate the workspace
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::STARTING, true]
        # There are multiple state transitions inside kubernetes
        # Fields like `replicas`, `unavailableReplicas` and `updatedReplicas` eventually become present
        <<~'YAML'
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          - lastTransitionTime: "2023-04-10T10:49:59Z"
            lastUpdateTime: "2023-04-10T10:49:59Z"
            message: Deployment does not have minimum availability.
            reason: MinimumReplicasUnavailable
            status: "False"
            type: Available
          observedGeneration: 3
          replicas: 1
          unavailableReplicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::RUNNING, true]
        <<~'YAML'
          availableReplicas: 1
          conditions:
          - lastTransitionTime: "2023-04-10T10:40:24Z"
            lastUpdateTime: "2023-04-10T10:40:35Z"
            message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
            reason: NewReplicaSetAvailable
            status: "True"
            type: Progressing
          - lastTransitionTime: "2023-04-10T10:50:10Z"
            lastUpdateTime: "2023-04-10T10:50:10Z"
            message: Deployment has minimum availability.
            reason: MinimumReplicasAvailable
            status: "True"
            type: Available
          observedGeneration: 3
          readyReplicas: 1
          replicas: 1
          updatedReplicas: 1
        YAML
      in [RemoteDevelopment::WorkspaceOperations::States::STARTING, RemoteDevelopment::WorkspaceOperations::States::FAILED, true]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STARTING, true]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [RemoteDevelopment::WorkspaceOperations::States::FAILED, RemoteDevelopment::WorkspaceOperations::States::STOPPING, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
      in [_, RemoteDevelopment::WorkspaceOperations::States::FAILED, _]
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError
        # <<~'YAML'
        #   conditions:
        #     - lastTransitionTime: "2023-03-06T14:36:31Z"
        #       lastUpdateTime: "2023-03-08T11:16:35Z"
        #       message: ReplicaSet "#{workspace.name}-hash" has successfully progressed.
        #       reason: NewReplicaSetAvailable
        #       status: "True"
        #       type: Progressing
        #     - lastTransitionTime: "2023-03-08T11:16:55Z"
        #       lastUpdateTime: "2023-03-08T11:16:55Z"
        #       message: Deployment does not have minimum availability.
        #       reason: MinimumReplicasUnavailable
        #       status: "False"
        #       type: Available
        #     replicas: 1
        #     unavailableReplicas: 1
        #     updatedReplicas: 1
        # YAML
      else
        msg =
          'Unsupported state transition passed for create_workspace_agent_info_hash fixture creation: ' \
            "actual_state: #{previous_actual_state} -> #{current_actual_state}, " \
            "existing_workspace: #{workspace_exists}"
        raise RemoteDevelopment::AgentInfoStatusFixtureNotImplementedError, msg
      end
    # rubocop:enable Lint/DuplicateBranch
    # rubocop:enable Layout/LineLength

    config_to_apply = create_config_to_apply(
      workspace: workspace,
      workspace_variables_environment: workspace_variables_environment,
      workspace_variables_file: workspace_variables_file,
      workspace_variables_additional_data: workspace_variables_additional_data,
      started: started,
      include_inventory: false,
      include_network_policy: false,
      include_all_resources: false,
      dns_zone: dns_zone
    )

    latest_k8s_deployment_info = config_to_apply.detect { |config| config.fetch(:kind) == 'Deployment' }
    latest_k8s_deployment_info[:metadata][:resourceVersion] = resource_version
    latest_k8s_deployment_info[:status] = yaml_safe_load_symbolized(status)

    # noinspection RubyMismatchedArgumentType -- For some reason it thinks a Hash key must have a String type?
    info[:latest_k8s_deployment_info] = latest_k8s_deployment_info
    info[:error_details] = error_details
    info
  end

  # rubocop:enable Metrics/ParameterLists, Metrics/PerceivedComplexity

  # @param [RemoteDevelopment::Workspace] workspace
  # @param [Hash] args
  # @return [String]
  def create_config_to_apply_yaml_stream(workspace:, **args)
    create_config_to_apply(workspace: workspace, **args).map { |resource| YAML.dump(resource.deep_stringify_keys) }.join
  end

  # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize, Metrics/PerceivedComplexity -- Cleanup as part of https://gitlab.com/gitlab-org/gitlab/-/issues/421687

  # @param [RemoteDevelopment::Workspace] workspace
  # @param [Boolean] started
  # @param [Boolean] desired_state_is_terminated
  # @param [Hash] workspace_variables_environment
  # @param [Hash] workspace_variables_file
  # @param [Hash] workspace_variables_additional_data
  # @param [Boolean] include_inventory
  # @param [Boolean] include_network_policy
  # @param [Boolean] include_all_resources
  # @param [String] dns_zone
  # param [Boolean] gitlab_workspaces_proxy_http_enabled
  # param [Boolean] gitlab_workspaces_proxy_ssh_enabled
  # @param [Array<Hash>] egress_ip_rules
  # @param [Hash] max_resources_per_workspace
  # @param [Hash] default_resources_per_workspace_container
  # @param [Boolean] allow_privilege_escalation
  # @param [Boolean] use_kubernetes_user_namespaces
  # @param [String] default_runtime_class
  # @param [Hash] agent_labels
  # @param [Hash] agent_annotations
  # @param [String] project_name
  # @param [String] namespace_path
  # @param [Array<Hash>] image_pull_secrets
  # @param [Boolean] include_scripts_resources
  # @param [Boolean] legacy_no_poststart_container_command
  # @param [Boolean] legacy_poststart_container_command
  # @param [Array<Hash>] user_defined_commands
  # @param [String] shared_namespace
  # @param [Boolean] core_resources_only
  # @return [Array<Hash>]
  def create_config_to_apply(
    workspace:,
    started: true,
    desired_state_is_terminated: false,
    workspace_variables_environment: nil,
    workspace_variables_file: nil,
    workspace_variables_additional_data: nil,
    include_inventory: true,
    include_network_policy: true,
    include_all_resources: false,
    dns_zone: 'workspaces.localdev.me',
    gitlab_workspaces_proxy_http_enabled: true,
    gitlab_workspaces_proxy_ssh_enabled: true,
    egress_ip_rules: [{
      allow: "0.0.0.0/0",
      except: %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16]
    }],
    max_resources_per_workspace: {},
    default_resources_per_workspace_container: {},
    allow_privilege_escalation: false,
    use_kubernetes_user_namespaces: false,
    default_runtime_class: "",
    agent_labels: {},
    agent_annotations: {},
    project_name: "test-project",
    namespace_path: "test-group",
    image_pull_secrets: [],
    include_scripts_resources: true,
    legacy_no_poststart_container_command: false,
    legacy_poststart_container_command: false,
    user_defined_commands: [],
    shared_namespace: "",
    core_resources_only: false
  )
    all_parameters =
      method(__method__.to_s)
        .parameters
        .map(&:last)
        .index_with { |name| binding.local_variable_get(name) }
        .to_h

    validate_hash_is_deep_symbolized(all_parameters)

    spec_replicas = started ? 1 : 0
    host_template_annotation = get_workspace_host_template_annotation(workspace.name, dns_zone)

    # NOTE: Match ConfigValuesExtractor's max-resources-per-workspace-sha256 computation: deep-sort the hash
    #       with Gitlab::Utils.deep_sort_hashes (the same primitive the extractor uses) and serialize with
    #       Gitlab::Json.dump rather than Hash#to_s. This keeps the digest stable across Ruby versions
    #       (Hash#to_s formatting changed in Ruby 3.4) and correct even when nested keys are not already sorted.
    max_resources_per_workspace_serialized = Gitlab::Json.dump(Gitlab::Utils.deep_sort_hashes(max_resources_per_workspace))

    common_annotations =
      Gitlab::Utils.deep_sort_hashes(
        agent_annotations.merge({
          "workspaces.gitlab.com/host-template": host_template_annotation,
          "workspaces.gitlab.com/id": workspace.id.to_s,
          "workspaces.gitlab.com/max-resources-per-workspace-sha256":
            Digest::SHA256.hexdigest(max_resources_per_workspace_serialized)
        })
      ).to_h
    workspace_inventory_annotations =
      Gitlab::Utils.deep_sort_hashes(
        common_annotations.merge({ "config.k8s.io/owning-inventory": "#{workspace.name}-workspace-inventory" })
      ).to_h

    common_annotations_for_partial_reconciliation = Gitlab::Utils.deep_sort_hashes(
      common_annotations.merge({ "workspaces.gitlab.com/include-in-partial-reconciliation" => "true" })
    )

    workspace_inventory_annotations_for_partial_reconciliation = Gitlab::Utils.deep_sort_hashes(
      workspace_inventory_annotations.merge({ "workspaces.gitlab.com/include-in-partial-reconciliation" => "true" })
    )

    labels = agent_labels.merge({ "agent.gitlab.com/id": workspace.agent.id.to_s })
    labels["workspaces.gitlab.com/id"] = workspace.id.to_s if shared_namespace.present?
    labels = Gitlab::Utils.deep_sort_hashes(labels).to_h

    secrets_inventory_annotations =
      Gitlab::Utils.deep_sort_hashes(
        common_annotations.merge({ "config.k8s.io/owning-inventory": "#{workspace.name}-secrets-inventory" })
      ).to_h

    # noinspection RubyMismatchedArgumentType -- RubyMine thinks annotation could be Array | Hash and it expects Hash
    workspace_inventory_config_map = workspace_inventory_config_map(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: common_annotations_for_partial_reconciliation
    )

    # noinspection RubyMismatchedArgumentType -- RubyMine thinks annotation could be Array | Hash and it expects Hash
    workspace_deployment = workspace_deployment(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: workspace_inventory_annotations_for_partial_reconciliation,
      spec_replicas: spec_replicas,
      default_resources_per_workspace_container: default_resources_per_workspace_container,
      allow_privilege_escalation: allow_privilege_escalation,
      use_kubernetes_user_namespaces: use_kubernetes_user_namespaces,
      default_runtime_class: default_runtime_class,
      include_scripts_resources: include_scripts_resources,
      legacy_no_poststart_container_command: legacy_no_poststart_container_command,
      legacy_poststart_container_command: legacy_poststart_container_command
    )

    # noinspection RubyMismatchedArgumentType -- RubyMine thinks annotation could be Array | Hash and it expects Hash
    workspace_service = workspace_service(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: workspace_inventory_annotations_for_partial_reconciliation
    )

    # noinspection RubyMismatchedArgumentType -- RubyMine thinks annotation could be Array | Hash and it expects Hash
    workspace_data_pvc = pvc(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: workspace_inventory_annotations_for_partial_reconciliation
    )

    # noinspection RubyMismatchedArgumentType -- RubyMine thinks annotation could be Array | Hash and it expects Hash
    workspace_service_account = workspace_service_account(
      name: workspace.name,
      namespace: workspace.namespace,
      image_pull_secrets: image_pull_secrets,
      labels: labels,
      annotations: workspace_inventory_annotations_for_partial_reconciliation
    )

    # noinspection RubyMismatchedArgumentType -- RubyMine thinks annotation could be Array | Hash and it expects Hash
    workspace_network_policy = workspace_network_policy(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: workspace_inventory_annotations_for_partial_reconciliation,
      egress_ip_rules: egress_ip_rules,
      gitlab_workspaces_proxy_http_enabled: gitlab_workspaces_proxy_http_enabled,
      gitlab_workspaces_proxy_ssh_enabled: gitlab_workspaces_proxy_ssh_enabled
    )

    # noinspection RubyMismatchedArgumentType -- RubyMine thinks annotation could be Array | Hash and it expects Hash
    scripts_configmap = scripts_configmap(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: workspace_inventory_annotations_for_partial_reconciliation,
      legacy_poststart_container_command: legacy_poststart_container_command,
      gitlab_workspaces_proxy_http_enabled: gitlab_workspaces_proxy_http_enabled,
      user_defined_commands: user_defined_commands
    )

    secrets_inventory_config_map = secrets_inventory_config_map(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: common_annotations
    )

    secret_environment = secret_environment(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: secrets_inventory_annotations,
      workspace_variables_environment: workspace_variables_environment || get_workspace_variables_environment(
        workspace_variables: workspace.workspace_variables
      )
    )

    secret_file = secret_file(
      workspace_name: workspace.name,
      workspace_namespace: workspace.namespace,
      labels: labels,
      annotations: secrets_inventory_annotations,
      workspace_variables_file: workspace_variables_file ||
        get_workspace_variables_file(workspace_variables: workspace.workspace_variables),
      additional_data: workspace_variables_additional_data ||
        {
          "#{workspace_operations_constants_module::WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_NAME}":
            workspace.actual_state
        }
    )

    if max_resources_per_workspace.present? && shared_namespace.empty?
      workspace_resource_quota = workspace_resource_quota(
        workspace_name: workspace.name,
        workspace_namespace: workspace.namespace,
        labels: labels,
        annotations: workspace_inventory_annotations,
        max_resources_per_workspace: max_resources_per_workspace
      )
    end

    resources = []
    resources << workspace_inventory_config_map if include_inventory

    if desired_state_is_terminated
      resources << secrets_inventory_config_map if include_inventory
      return resources
    end

    resources << workspace_deployment
    resources << workspace_service
    resources << workspace_data_pvc

    unless core_resources_only
      resources << workspace_service_account
      resources << workspace_network_policy if include_network_policy
      resources << scripts_configmap if include_scripts_resources

      if include_all_resources
        resources << secrets_inventory_config_map if include_inventory
        resources << workspace_resource_quota if workspace_resource_quota
        resources << secret_environment
        resources << secret_file
      end
    end

    normalize_resources(namespace_path, project_name, resources)
  end

  # rubocop:enable Metrics/ParameterLists, Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/PerceivedComplexity

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @return [Hash]
  def workspace_inventory_config_map(workspace_name:, workspace_namespace:, labels:, annotations:)
    {
      apiVersion: "v1",
      kind: "ConfigMap",
      metadata: {
        annotations: annotations,
        labels: Gitlab::Utils.deep_sort_hashes(
          labels.merge(
            {
              "cli-utils.sigs.k8s.io/inventory-id": "#{workspace_name}-workspace-inventory"
            }
          )
        ),
        name: "#{workspace_name}-workspace-inventory",
        namespace: workspace_namespace
      }
    }
  end

  # rubocop:disable Metrics/ParameterLists,Metrics/AbcSize -- Cleanup as part of https://gitlab.com/gitlab-org/gitlab/-/issues/421687

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Boolean] allow_privilege_escalation
  # @param [Hash] annotations
  # @param [Hash] default_resources_per_workspace_container
  # @param [String] default_runtime_class
  # @param [Boolean] include_scripts_resources
  # @param [Boolean] legacy_no_poststart_container_command
  # @param [Boolean] legacy_poststart_container_command
  # @param [Hash] labels
  # @param [Integer] spec_replicas
  # @param [Boolean] use_kubernetes_user_namespaces
  # @return [Hash]
  def workspace_deployment(
    workspace_name:,
    workspace_namespace:,
    allow_privilege_escalation: false,
    annotations: {},
    default_resources_per_workspace_container: {},
    default_runtime_class: "",
    include_scripts_resources: true,
    legacy_no_poststart_container_command: false,
    legacy_poststart_container_command: false,
    labels: {},
    spec_replicas: 1,
    use_kubernetes_user_namespaces: false
  )
    container_security_context = {
      'allowPrivilegeEscalation' => allow_privilege_escalation,
      'privileged' => false,
      'runAsNonRoot' => true,
      'runAsUser' => create_constants_module::RUN_AS_USER
    }

    deployment = {
      apiVersion: "apps/v1",
      kind: "Deployment",
      metadata: {
        annotations: annotations,
        labels: labels,
        name: workspace_name,
        namespace: workspace_namespace
      },
      spec: {
        replicas: spec_replicas,
        selector: {
          matchLabels: labels
        },
        strategy: {
          type: "Recreate"
        },
        template: {
          metadata: {
            annotations: annotations,
            labels: labels,
            name: workspace_name,
            namespace: workspace_namespace
          },
          spec: {
            hostUsers: use_kubernetes_user_namespaces,
            runtimeClassName: default_runtime_class,
            containers: [
              {
                args: [files_module::CONTAINER_KEEPALIVE_COMMAND_ARGS],
                command: %w[/bin/sh -c],
                env: [
                  {
                    name: "PROJECT_SOURCE",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  },
                  {
                    name: "PROJECTS_ROOT",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  },
                  {
                    name: create_constants_module::TOOLS_DIR_ENV_VAR,
                    value: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
                      "#{create_constants_module::TOOLS_DIR_NAME}"
                  },
                  {
                    name: "GL_VSCODE_LOG_LEVEL",
                    value: "info"
                  },
                  {
                    name: "GL_VSCODE_PORT",
                    value: create_constants_module::WORKSPACE_EDITOR_PORT.to_s
                  },
                  {
                    name: "GL_SSH_PORT",
                    value: create_constants_module::WORKSPACE_SSH_PORT.to_s
                  },
                  {
                    name: "GL_VSCODE_ENABLE_MARKETPLACE",
                    value: "false"
                  }
                ],
                image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                imagePullPolicy: "Always",
                name: "tooling-container",
                ports: [
                  {
                    containerPort: create_constants_module::WORKSPACE_EDITOR_PORT,
                    name: "editor-server",
                    protocol: "TCP"
                  },
                  {
                    containerPort: create_constants_module::WORKSPACE_SSH_PORT,
                    name: "ssh-server",
                    protocol: "TCP"
                  }
                ],
                resources: default_resources_per_workspace_container,
                volumeMounts: [
                  {
                    mountPath: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH,
                    name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME
                  },
                  {
                    mountPath: workspace_operations_constants_module::VARIABLES_VOLUME_PATH,
                    name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME
                  },
                  {
                    mountPath: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH,
                    name: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ],
                lifecycle: {
                  postStart: {
                    exec: {
                      command: [
                        "/bin/sh",
                        "-c",
                        format(
                          files_module::KUBERNETES_POSTSTART_HOOK_COMMAND,
                          run_internal_blocking_poststart_commands_script_file_path:
                            "#{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/" \
                              "#{create_constants_module::RUN_INTERNAL_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}", # rubocop:disable Layout/LineEndStringConcatenationIndentation -- Match default RubyMine formatting
                          run_non_blocking_poststart_commands_script_file_path:
                            "#{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/" \
                              "#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}", # rubocop:disable Layout/LineEndStringConcatenationIndentation -- Match default RubyMine formatting
                          component_name: "tooling-container",
                          main_component_name: "tooling-container"
                        )
                      ]
                    }
                  }
                }
              },
              {
                env: [
                  {
                    name: "PROJECT_SOURCE",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  },
                  {
                    name: "PROJECTS_ROOT",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  },
                  {
                    name: "MYSQL_ROOT_PASSWORD",
                    value: "my-secret-pw"
                  }
                ],
                image: "mysql",
                imagePullPolicy: "Always",
                name: "database-container",
                resources: default_resources_per_workspace_container,
                volumeMounts: [
                  {
                    mountPath: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH,
                    name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME
                  },
                  {
                    mountPath: workspace_operations_constants_module::VARIABLES_VOLUME_PATH,
                    name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME
                  },
                  {
                    mountPath: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH,
                    name: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ],
                lifecycle: {
                  postStart: {
                    exec: {
                      command: [
                        "/bin/sh",
                        "-c",
                        format(
                          files_module::KUBERNETES_POSTSTART_HOOK_COMMAND,
                          run_internal_blocking_poststart_commands_script_file_path:
                            "#{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/database-container/" \
                              "#{create_constants_module::RUN_INTERNAL_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}", # rubocop:disable Layout/LineEndStringConcatenationIndentation -- Match default RubyMine formatting
                          run_non_blocking_poststart_commands_script_file_path:
                            "#{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/database-container/" \
                              "#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}", # rubocop:disable Layout/LineEndStringConcatenationIndentation -- Match default RubyMine formatting
                          component_name: "database-container",
                          main_component_name: "tooling-container"
                        )
                      ]
                    }
                  }
                }
              },
              {
                image: "quay.io/mloriedo/universal-developer-image:ubi8-dw-demo",
                imagePullPolicy: "Always",
                name: "user-defined-entrypoint-cmd-component",
                resources: default_resources_per_workspace_container,
                command: ["echo"],
                args: ["-n", "user-defined entrypoint command"],
                env: [
                  {
                    name: "PROJECT_SOURCE",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  },
                  {
                    name: "PROJECTS_ROOT",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ],
                volumeMounts: [
                  {
                    mountPath: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH,
                    name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME
                  },
                  {
                    mountPath: workspace_operations_constants_module::VARIABLES_VOLUME_PATH,
                    name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME
                  },
                  {
                    mountPath: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH,
                    name: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME
                  }
                ]
              }
            ],
            initContainers: [
              {
                env: [
                  {
                    name: "PROJECT_SOURCE",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  },
                  {
                    name: "PROJECTS_ROOT",
                    value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
                  },
                  {
                    name: create_constants_module::TOOLS_DIR_ENV_VAR,
                    value: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
                      "#{create_constants_module::TOOLS_DIR_NAME}"
                  }
                ],
                image: workspace_operations_constants_module::WORKSPACE_TOOLS_IMAGE,
                imagePullPolicy: "Always",
                name: "gl-tools-injector-gl-tools-injector-command-1",
                resources: {
                  limits: {
                    cpu: "500m",
                    memory: "512Mi"
                  },
                  requests: {
                    cpu: "100m",
                    memory: "256Mi"
                  }
                },
                volumeMounts: [
                  {
                    mountPath: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH,
                    name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME
                  },
                  {
                    mountPath: workspace_operations_constants_module::VARIABLES_VOLUME_PATH,
                    name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME
                  }
                ],
                securityContext: container_security_context,
                envFrom: [
                  {
                    secretRef: {
                      name: "#{workspace_name}-env-var"
                    }
                  }
                ]
              }
            ],
            serviceAccountName: workspace_name,
            volumes: [
              {
                name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME,
                persistentVolumeClaim: {
                  claimName: "#{workspace_name}-#{create_constants_module::WORKSPACE_DATA_VOLUME_NAME}"
                }
              },
              {
                name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME,
                projected: {
                  defaultMode: workspace_operations_constants_module::VARIABLES_VOLUME_DEFAULT_MODE,
                  sources: [
                    {
                      secret: {
                        name: "#{workspace_name}-file"
                      }
                    }
                  ]
                }
              },
              {
                name: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME,
                projected: {
                  defaultMode: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_DEFAULT_MODE,
                  sources: [
                    {
                      configMap: {
                        name: "#{workspace_name}-scripts-configmap",
                        items: [
                          {
                            key: "gl-clone-project-command",
                            path: "tooling-container/gl-clone-project-command"
                          },
                          {
                            key: "gl-clone-unshallow-command",
                            path: "tooling-container/gl-clone-unshallow-command"
                          },
                          {
                            key: "gl-start-sshd-command",
                            path: "tooling-container/gl-start-sshd-command"
                          },
                          {
                            key: "gl-init-tools-command",
                            path: "tooling-container/gl-init-tools-command"
                          },
                          {
                            key: "gl-sleep-until-container-is-running-command",
                            path: "tooling-container/gl-sleep-until-container-is-running-command"
                          },
                          {
                            key: "db-component-command-with-working-dir",
                            path: "database-container/db-component-command-with-working-dir"
                          },
                          {
                            key: "db-component-command-without-working-dir",
                            path: "database-container/db-component-command-without-working-dir"
                          },
                          {
                            key: "main-component-command-without-working-dir",
                            path: "tooling-container/main-component-command-without-working-dir"
                          },
                          {
                            key: "user-defined-command",
                            path: "tooling-container/user-defined-command"
                          },
                          {
                            key: "tooling-container-gl-run-internal-blocking-poststart-commands.sh",
                            path: "tooling-container/gl-run-internal-blocking-poststart-commands.sh"
                          },
                          {
                            key: "tooling-container-gl-run-non-blocking-poststart-commands.sh",
                            path: "tooling-container/gl-run-non-blocking-poststart-commands.sh"
                          },
                          {
                            key: "database-container-gl-run-non-blocking-poststart-commands.sh",
                            path: "database-container/gl-run-non-blocking-poststart-commands.sh"
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            ],
            securityContext: {
              runAsNonRoot: true,
              runAsUser: create_constants_module::RUN_AS_USER,
              fsGroup: 0,
              fsGroupChangePolicy: "OnRootMismatch"
            }
          }
        }
      },
      status: {}
    }

    database_container = deployment[:spec][:template][:spec][:containers].find { |c| c[:name] == "database-container" }

    unless include_scripts_resources
      deployment[:spec][:template][:spec][:containers].each do |container|
        container[:volumeMounts].delete_if do |volume_mount|
          volume_mount[:name] == create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME
        end
      end
      deployment[:spec][:template][:spec][:volumes].delete_if do |volume|
        volume[:name] == create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME
      end
      deployment[:spec][:template][:spec][:containers][0].delete(:lifecycle)
      database_container&.delete(:lifecycle)
    end

    if legacy_poststart_container_command
      database_container&.delete(:lifecycle)
      deployment[:spec][:template][:spec][:containers][0][:lifecycle] = {
        postStart: {
          exec: {
            command: [
              "/bin/sh",
              "-c",
              format(
                files_module::KUBERNETES_LEGACY_POSTSTART_HOOK_COMMAND,
                run_internal_blocking_poststart_commands_script_file_path:
                  "#{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/" \
                    "#{create_constants_module::LEGACY_RUN_POSTSTART_COMMANDS_SCRIPT_NAME}" # rubocop:disable Layout/LineEndStringConcatenationIndentation -- Match default RubyMine formatting
              )
            ]
          }
        }
      }
      deployment[:spec][:template][:spec][:containers][1][:lifecycle]

      scripts_volume = deployment[:spec][:template][:spec][:volumes].find do |volume|
        volume[:name] == create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME
      end

      scripts_volume[:projected][:sources][0][:configMap].delete(:items) if scripts_volume
    end

    if legacy_no_poststart_container_command
      # Add the container args for the container where tools are injected
      deployment[:spec][:template][:spec][:containers][0][:args][0] =
        <<~YAML.chomp
          #{files_module::INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT}
          #{files_module::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT}
        YAML

      # Insert the project cloning as the first init container
      project_cloner_script_content = files_module::INTERNAL_POSTSTART_COMMAND_CLONE_PROJECT_SCRIPT.dup
      project_cloner_script_content.gsub!("#!/bin/sh\n", "")
      format_clone_project_script!(project_cloner_script_content)

      project_cloning_init_container = {
        args: [project_cloner_script_content],
        command: %w[/bin/sh -c],
        env: [
          {
            name: "PROJECT_SOURCE",
            value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
          },
          {
            name: "PROJECTS_ROOT",
            value: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
          }
        ],
        image: "alpine/git:2.45.2",
        imagePullPolicy: "Always",
        name: "gl-project-cloner-gl-project-cloner-command-1",
        resources: {
          limits: {
            cpu: "500m",
            memory: "1000Mi"
          },
          requests: {
            cpu: "100m",
            memory: "500Mi"
          }
        },
        volumeMounts: [
          {
            mountPath: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH,
            name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME
          },
          {
            mountPath: workspace_operations_constants_module::VARIABLES_VOLUME_PATH,
            name: workspace_operations_constants_module::VARIABLES_VOLUME_NAME
          }
        ],
        securityContext: container_security_context,
        envFrom: [
          {
            secretRef: {
              name: "#{workspace_name}-env-var"
            }
          }
        ]
      }
      deployment[:spec][:template][:spec][:initContainers].prepend(project_cloning_init_container)
      deployment[:spec][:template][:spec][:initContainers][1][:name] = "gl-tools-injector-gl-tools-injector-command-2"
    end

    deployment[:spec][:template][:spec].delete(:runtimeClassName) if default_runtime_class.empty?
    deployment[:spec][:template][:spec].delete(:hostUsers) unless use_kubernetes_user_namespaces

    deployment
  end

  # rubocop:enable Metrics/ParameterLists,Metrics/AbcSize

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @return [Hash]
  def workspace_service(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:
  )
    {
      apiVersion: "v1",
      kind: "Service",
      metadata: {
        annotations: annotations,
        labels: labels,
        name: workspace_name,
        namespace: workspace_namespace
      },
      spec: {
        ports: [
          {
            name: "editor-server",
            port: create_constants_module::WORKSPACE_EDITOR_PORT,
            targetPort: create_constants_module::WORKSPACE_EDITOR_PORT
          },
          {
            name: "ssh-server",
            port: create_constants_module::WORKSPACE_SSH_PORT,
            targetPort: create_constants_module::WORKSPACE_SSH_PORT
          }
        ],
        selector: labels
      },
      status: {
        loadBalancer: {}
      }
    }
  end

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @return [Hash]
  def pvc(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:
  )
    {
      apiVersion: "v1",
      kind: "PersistentVolumeClaim",
      metadata: {
        annotations: annotations,
        labels: labels,
        name: "#{workspace_name}-#{create_constants_module::WORKSPACE_DATA_VOLUME_NAME}",
        namespace: workspace_namespace
      },
      spec: {
        accessModes: [
          "ReadWriteOnce"
        ],
        resources: {
          requests: {
            storage: "50Gi"
          }
        }
      },
      status: {}
    }
  end

  # @param [String] name
  # @param [String] namespace
  # @param [Array<Hash>] image_pull_secrets
  # @param [Hash] labels
  # @param [Hash] annotations
  # @return [Hash]
  def workspace_service_account(
    name:,
    namespace:,
    image_pull_secrets:,
    labels:,
    annotations:
  )
    image_pull_secrets_names = image_pull_secrets.map { |secret| { name: secret.symbolize_keys.fetch(:name) } }
    {
      kind: 'ServiceAccount',
      apiVersion: 'v1',
      metadata: {
        name: name,
        namespace: namespace,
        annotations: annotations,
        labels: labels
      },
      automountServiceAccountToken: false,
      imagePullSecrets: image_pull_secrets_names
    }
  end

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @param [Array<Hash>] egress_ip_rules
  # @param [Boolean] gitlab_workspaces_proxy_http_enabled
  # @param [Boolean] gitlab_workspaces_proxy_ssh_enabled
  # @return [Hash]
  def workspace_network_policy(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    egress_ip_rules:,
    gitlab_workspaces_proxy_http_enabled:,
    gitlab_workspaces_proxy_ssh_enabled:
  )
    policy_types = []
    ingress = []
    if gitlab_workspaces_proxy_http_enabled || gitlab_workspaces_proxy_ssh_enabled
      policy_types.append("Ingress")
      proxy_namespace_selector = {
        matchLabels: {
          "kubernetes.io/metadata.name": "gitlab-workspaces"
        }
      }
      proxy_pod_selector = {
        matchLabels: {
          "app.kubernetes.io/name": "gitlab-workspaces-proxy"
        }
      }
      ingress.append(
        { from: [{ namespaceSelector: proxy_namespace_selector, podSelector: proxy_pod_selector }] }
      )
    end

    policy_types.append("Egress")
    kube_system_namespace_selector = {
      matchLabels: {
        "kubernetes.io/metadata.name": "kube-system"
      }
    }
    egress = [
      {
        ports: [{ port: 53, protocol: "TCP" }, { port: 53, protocol: "UDP" }],
        to: [{ namespaceSelector: kube_system_namespace_selector }]
      }
    ]

    egress_ip_rules.each do |egress_rule|
      symbolized_egress_rule = egress_rule.deep_symbolize_keys
      egress.append(
        { to: [{ ipBlock: { cidr: symbolized_egress_rule[:allow], except: symbolized_egress_rule[:except] } }] }
      )
    end

    # Use the workspace_id as a pod selector if it is present
    workspace_id = labels.fetch("workspaces.gitlab.com/id", nil)
    pod_selector = {}
    if workspace_id.present?
      pod_selector[:matchLabels] = {
        "workspaces.gitlab.com/id": workspace_id
      }
    end

    {
      apiVersion: "networking.k8s.io/v1",
      kind: "NetworkPolicy",
      metadata: {
        annotations: annotations,
        labels: labels,
        name: workspace_name,
        namespace: workspace_namespace
      },
      spec: {
        egress: egress,
        ingress: ingress,
        podSelector: pod_selector,
        policyTypes: policy_types
      }
    }
  end

  # @param [Array<Hash>] devfile_commands
  # @param [Hash] devfile_events
  # @return [Array<Hash>]
  def extract_user_defined_poststart_commands(devfile_commands:, devfile_events:)
    poststart_command_ids = devfile_events.fetch(:postStart)

    poststart_commands = poststart_command_ids.filter_map do |id|
      devfile_commands.find { |cmd| cmd[:id] == id }
    end

    _, non_blocking_commands = poststart_commands.partition do |poststart_cmd|
      poststart_cmd&.dig(:exec, :label)&.starts_with?(workspace_operations_constants_module::INTERNAL_COMMAND_LABEL)
    end

    non_blocking_commands
  end

  # @return [String]
  def internal_blocking_poststart_commands_script
    data_volume_path = workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
    <<~SCRIPT
      #!/bin/sh
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-clone-project-command..."
      (cd #{data_volume_path} && #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-clone-project-command) || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-clone-project-command."
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-clone-unshallow-command..."
      (cd #{data_volume_path} && #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-clone-unshallow-command) || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-clone-unshallow-command."
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-start-sshd-command..."
      (cd #{data_volume_path} && #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-start-sshd-command) || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-start-sshd-command."
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-init-tools-command..."
      (cd #{data_volume_path} && #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-init-tools-command) || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-init-tools-command."
    SCRIPT
  end

  # @param [Array<String>] user_command_ids
  # @param [Array<Hash>] devfile_commands
  # @param [String] project_path
  # @param [String] main_component_name
  # @return [String]
  def non_blocking_poststart_commands_script(
    poststart_commands:,
    project_path: "test-project",
    component_name: "tooling-container",
    main_component_name: "tooling-container"
  )
    data_volume_path = workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH

    script = <<~SCRIPT
          #!/bin/sh
    SCRIPT

    if component_name == main_component_name
      script += <<~SCRIPT
          echo "$(date -Iseconds): ----------------------------------------"
          echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-sleep-until-container-is-running-command..."
          (cd #{data_volume_path} && #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-sleep-until-container-is-running-command) || true
          echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/tooling-container/gl-sleep-until-container-is-running-command."
      SCRIPT
    end

    # Add user-defined commands if any
    poststart_commands.each do |command|
      working_dir = command.dig(:exec, :workingDir)
      command_component_name = command.dig(:exec, :component)

      next unless command_component_name == component_name

      poststart_command_path = "#{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/" \
        "#{component_name}/#{command[:id]}"
      script_execution = poststart_command_path

      effective_working_dir = if working_dir.present?
                                working_dir
                              elsif component_name == main_component_name
                                "${PROJECT_SOURCE}/#{Shellwords.shellescape(project_path)}"
                              end

      script_execution = "(cd #{effective_working_dir} && #{poststart_command_path})" if effective_working_dir.present?

      script += <<~SCRIPT
        echo "$(date -Iseconds): ----------------------------------------"
        echo "$(date -Iseconds): Running #{poststart_command_path}..."
        #{script_execution} || true
        echo "$(date -Iseconds): Finished running #{poststart_command_path}."
      SCRIPT
    end

    script
  end

  # @return [String]
  def legacy_poststart_commands_script
    <<~SCRIPT
      #!/bin/sh
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-clone-project-command..."
      #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-clone-project-command || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-clone-project-command."
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-start-sshd-command..."
      #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-start-sshd-command || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-start-sshd-command."
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-init-tools-command..."
      #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-init-tools-command || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-init-tools-command."
      echo "$(date -Iseconds): ----------------------------------------"
      echo "$(date -Iseconds): Running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-sleep-until-container-is-running-command..."
      #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-sleep-until-container-is-running-command || true
      echo "$(date -Iseconds): Finished running #{create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH}/gl-sleep-until-container-is-running-command."
    SCRIPT
  end

  # @return [String]
  def clone_project_script
    volume_path = workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
    project_cloning_successful_file = "#{volume_path}/#{create_constants_module::PROJECT_CLONING_SUCCESSFUL_FILE_NAME}"
    clone_dir = "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/test-project"
    project_ref = "master"
    project_url = "#{root_url}test-group/test-project.git"
    format(
      RemoteDevelopment::Files::INTERNAL_POSTSTART_COMMAND_CLONE_PROJECT_SCRIPT,
      project_cloning_successful_file: Shellwords.shellescape(project_cloning_successful_file),
      clone_dir: Shellwords.shellescape(clone_dir),
      project_ref: Shellwords.shellescape(project_ref),
      project_url: Shellwords.shellescape(project_url),
      clone_depth_option: create_constants_module::CLONE_DEPTH_OPTION
    )
  end

  # @return [String]
  def clone_unshallow_script
    volume_path = workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
    project_cloning_successful_file = "#{volume_path}/#{create_constants_module::PROJECT_CLONING_SUCCESSFUL_FILE_NAME}"
    clone_dir = "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/test-project"
    format(
      RemoteDevelopment::Files::INTERNAL_POSTSTART_COMMAND_CLONE_UNSHALLOW_SCRIPT,
      project_cloning_successful_file: Shellwords.shellescape(project_cloning_successful_file),
      clone_dir: Shellwords.shellescape(clone_dir),
      main_component_name: Shellwords.shellescape("tooling-container")
    )
  end

  # @return [String]
  def sleep_until_container_is_running_script
    format(
      RemoteDevelopment::Files::INTERNAL_POSTSTART_COMMAND_SLEEP_UNTIL_WORKSPACE_IS_RUNNING_SCRIPT,
      workspace_reconciled_actual_state_file_path:
        workspace_operations_constants_module::WORKSPACE_RECONCILED_ACTUAL_STATE_FILE_PATH
    )
  end

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @param [Boolean] legacy_poststart_container_command
  # @param [Boolean] gitlab_workspaces_proxy_http_enabled
  # @param [Array<Hash>] user_defined_commands
  # @return [Hash]
  def scripts_configmap(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    legacy_poststart_container_command:,
    gitlab_workspaces_proxy_http_enabled:,
    user_defined_commands:
  )
    data = {
      "gl-start-agentw-command": files_module::INTERNAL_POSTSTART_COMMAND_START_AGENTW_SCRIPT,
      "gl-clone-project-command": clone_project_script,
      "gl-clone-unshallow-command": clone_unshallow_script,
      "gl-init-tools-command": format(files_module::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT,
        main_component_name: Shellwords.shellescape("tooling-container")),
      "gl-start-sshd-command": format(files_module::INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT,
        main_component_name: Shellwords.shellescape("tooling-container")),
      "tooling-container-#{create_constants_module::RUN_INTERNAL_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}":
        internal_blocking_poststart_commands_script,
      "tooling-container-#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}":
        non_blocking_poststart_commands_script(
          poststart_commands: user_defined_commands
        ),
      "gl-sleep-until-container-is-running-command": sleep_until_container_is_running_script
    }

    if legacy_poststart_container_command
      data.delete(:"tooling-container-#{create_constants_module::RUN_INTERNAL_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}")
      data.delete(:"tooling-container-#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}")
      data.delete(:"gl-clone-unshallow-command")
      data[create_constants_module::LEGACY_RUN_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym] =
        legacy_poststart_commands_script
      data[:"gl-init-tools-command"] = files_module::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT
      data[:"gl-start-sshd-command"] = files_module::INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT
    end

    container_names_with_poststart_commands = user_defined_commands.map { |cmd| cmd[:exec][:component] }.uniq

    container_names_with_poststart_commands.each do |container|
      next if container == "tooling-container"

      data[:"#{container}-#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}"] =
        non_blocking_poststart_commands_script(
          poststart_commands: user_defined_commands,
          component_name: container
        )
    end

    data.delete(:"gl-start-agentw-command") if gitlab_workspaces_proxy_http_enabled

    # Add each user-defined command to the data hash
    user_defined_commands.each do |cmd|
      data[cmd[:id].to_sym] = cmd[:exec][:commandLine]
    end

    {
      apiVersion: "v1",
      kind: "ConfigMap",
      metadata: {
        annotations: annotations,
        labels: labels,
        name: "#{workspace_name}-scripts-configmap",
        namespace: workspace_namespace
      },
      data: data
    }
  end

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @return [Hash]
  def secrets_inventory_config_map(workspace_name:, workspace_namespace:, labels:, annotations:)
    {
      apiVersion: "v1",
      kind: "ConfigMap",
      metadata: {
        annotations: annotations,
        labels:
          Gitlab::Utils.deep_sort_hashes(
            labels.merge({ "cli-utils.sigs.k8s.io/inventory-id": "#{workspace_name}-secrets-inventory" })
          ),
        name: "#{workspace_name}-secrets-inventory",
        namespace: workspace_namespace
      }
    }
  end

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @param [Hash] max_resources_per_workspace
  # @return [Hash]
  def workspace_resource_quota(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    max_resources_per_workspace:
  )
    max_resources_per_workspace => {
      limits: {
        cpu: limits_cpu,
        memory: limits_memory
      },
      requests: {
        cpu: requests_cpu,
        memory: requests_memory
      }
    }

    {
      apiVersion: "v1",
      kind: "ResourceQuota",
      metadata: {
        annotations: annotations,
        labels: labels,
        name: workspace_name,
        namespace: workspace_namespace
      },
      spec: {
        hard: {
          "limits.cpu": limits_cpu,
          "limits.memory": limits_memory,
          "requests.cpu": requests_cpu,
          "requests.memory": requests_memory
        }
      }
    }
  end

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @param [Hash] workspace_variables_environment
  # @return [Hash]
  def secret_environment(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    workspace_variables_environment:
  )
    # TODO: figure out why there is flakiness in the order of the environment variables -- https://gitlab.com/gitlab-org/gitlab/-/issues/451934
    {
      kind: "Secret",
      apiVersion: "v1",
      metadata: {
        name: "#{workspace_name}-env-var",
        namespace: workspace_namespace,
        labels: labels,
        annotations: annotations
      },
      data: workspace_variables_environment.transform_values { |v| Base64.strict_encode64(v) }
    }
  end

  # @param [String] workspace_name
  # @param [String] workspace_namespace
  # @param [Hash] labels
  # @param [Hash] annotations
  # @param [Hash] workspace_variables_file
  # @param [Hash] additional_data
  # @return [Hash]
  def secret_file(
    workspace_name:,
    workspace_namespace:,
    labels:,
    annotations:,
    workspace_variables_file:,
    additional_data:
  )
    data = workspace_variables_file.merge(additional_data)

    {
      kind: "Secret",
      apiVersion: "v1",
      metadata: {
        name: "#{workspace_name}-file",
        namespace: workspace_namespace,
        labels: labels,
        annotations: annotations
      },
      data: data.transform_values { |v| Base64.strict_encode64(v) }
    }
  end

  # @param [String] namespace_path
  # @param [String] project_name
  # @param [Array<Hash>] resources
  # @return [Array<Hash>]
  def normalize_resources(namespace_path, project_name, resources)
    # Convert to YAML to normalize project_name, namespace_path, and root_url
    normalized_resources_yaml = resources.map do |resource|
      yaml = YAML.dump(resource)
      yaml.gsub!('test-project', project_name)
      yaml.gsub!('test-group', namespace_path)
      yaml.gsub!('http://localhost/', root_url)
      yaml
    end.join

    # Convert back to array of hashes, symbolizing keys, and deep sorting for test fixture comparison stability
    YAML.load_stream(normalized_resources_yaml).map do |resource|
      sorted_then_symbolized_resource = Gitlab::Utils.deep_sort_hash(resource).deep_symbolize_keys
      symbolized_then_sorted_resource = Gitlab::Utils.deep_sort_hash(resource.deep_symbolize_keys)

      # Verify there's no unexpected sorting instability for symbols vs. strings
      raise "Sorting stability order error!" unless sorted_then_symbolized_resource == symbolized_then_sorted_resource

      sorted_then_symbolized_resource
    end
  end

  # @param [ActiveRecord::Relation] workspace_variables
  # @return [Hash]
  def get_workspace_variables_environment(workspace_variables:)
    workspace_variables.with_variable_type_environment.each_with_object({}) do |workspace_variable, hash|
      hash[workspace_variable.key.to_sym] = workspace_variable.value
    end
  end

  # @param [ActiveRecord::Relation] workspace_variables
  # @return [Hash]
  def get_workspace_variables_file(workspace_variables:)
    workspace_variables.with_variable_type_file.each_with_object({}) do |workspace_variable, hash|
      hash[workspace_variable.key.to_sym] = workspace_variable.value
    end
  end

  # @param [String] workspace_name
  # @param [String] dns_zone
  # @return [String]
  def get_workspace_host_template_annotation(workspace_name, dns_zone)
    "{{.port}}-#{workspace_name}.#{dns_zone}"
  end

  # @param [String] workspace_name
  # @param [String] dns_zone
  # @return [String]
  def get_workspace_host_template_environment(workspace_name, dns_zone)
    "${PORT}-#{workspace_name}.#{dns_zone}"
  end

  # @param [String] yaml
  # @return [Hash]
  def yaml_safe_load_symbolized(yaml)
    raise "Use #yaml_safe_load_stream_symbolized for YAML streams (arrays)" unless YAML.load_stream(yaml).size == 1

    YAML.safe_load(yaml).deep_symbolize_keys
  end

  # @param [String] yaml
  # @return [Array<Hash>]
  def yaml_safe_load_stream_symbolized(yaml)
    raise "Use #yaml_safe_load_symbolized for YAML docs (hashes)" unless YAML.load_stream(yaml).size > 1

    YAML.load_stream(yaml).map { |doc| YAML.safe_load(YAML.dump(doc)).deep_symbolize_keys }
  end

  # @return [String]
  def example_default_devfile_yaml
    read_devfile_yaml('example.default_devfile.yaml.erb')
  end

  # @return [String]
  def example_devfile_yaml
    read_devfile_yaml('example.devfile.yaml.erb')
  end

  # @return [Hash]
  def example_devfile
    yaml_safe_load_symbolized(example_devfile_yaml)
  end

  # @return [String]
  def example_flattened_devfile_yaml
    read_devfile_yaml("example.flattened-devfile.yaml.erb")
  end

  # @return [Hash]
  def example_flattened_devfile
    yaml_safe_load_symbolized(example_flattened_devfile_yaml)
  end

  # @param [String] project_name
  # @param [String] namespace_path
  # @return [String]
  def example_processed_devfile_yaml(project_name: "test-project", namespace_path: "test-group")
    read_devfile_yaml(
      "example.processed-devfile.yaml.erb",
      project_name: project_name,
      namespace_path: namespace_path
    )
  end

  # @param [String] project_name
  # @param [String] namespace_path
  # @return [Hash]
  def example_processed_devfile(project_name: "test-project", namespace_path: "test-group")
    yaml_safe_load_symbolized(
      example_processed_devfile_yaml(project_name: project_name, namespace_path: namespace_path)
    )
  end

  # @param [String] filename
  # @param [String] project_name
  # @param [String] namespace_path
  # @return [Hash]
  def read_devfile(filename, project_name: "test-project", namespace_path: "test-group")
    yaml_safe_load_symbolized(
      read_devfile_yaml(filename, project_name: project_name, namespace_path: namespace_path)
    )
  end

  # @param [Hash] hash
  # @return [void]
  def validate_hash_is_deep_symbolized(hash)
    hash.each do |key, value|
      next unless value.is_a?(Hash) || value.is_a?(Array)

      unless { key => value } == { key => value }.deep_symbolize_keys
        fix = value.is_a?(Hash) ? '.deep_symbolize_keys' : '.map(&:deep_symbolize_keys)'
        raise "#{key} must be deep_symbolized - call '#{fix}' on it as early as possible (where it is first read)"
      end
    end

    nil
  end
end
