# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/helpers/remote_development/integration_spec_helpers"

# rubocop:disable RSpec/MultipleMemoizedHelpers -- this is an integration test, it has a lot of fixtures, but only one example, so we don't need let_it_be
RSpec.describe "Full workspaces integration request spec", :freeze_time, feature_category: :workspaces do
  include GraphqlHelpers
  include RemoteDevelopment::IntegrationSpecHelpers
  include_context "with remote development shared fixtures"

  let(:agentw_token) { "" }
  let(:agentw_observability_listen_address) { create_constants_module::AGENTW_OBSERVABILITY_LISTEN_ADDRESS }
  let(:agentw_token_file_path) { create_constants_module::AGENTW_TOKEN_FILE_PATH }
  let(:gitlab_kas_external_url) { RemoteDevelopment::Settings.get_single_setting(:gitlab_kas_external_url) }
  let(:token_file_name) { create_constants_module::TOKEN_FILE_NAME }
  let(:token_file_path) { create_constants_module::TOKEN_FILE_PATH }
  let(:git_credential_store_script) { files_module::GIT_CREDENTIAL_STORE_SCRIPT }
  let(:git_credential_store_script_file_name) do
    create_constants_module::GIT_CREDENTIAL_STORE_SCRIPT_FILE_NAME
  end

  let(:git_credential_store_script_file_path) do
    create_constants_module::GIT_CREDENTIAL_STORE_SCRIPT_FILE_PATH
  end

  let(:states) { states_module }
  let(:agent_admin_user) { create(:user, name: "Agent Admin User") }
  # Agent setup
  let(:jwt_secret) { SecureRandom.random_bytes(Gitlab::Kas::SECRET_LENGTH) }
  let(:agent_token) { create(:cluster_agent_token, agent: agent) }

  let(:dns_zone) { "integration-spec-workspaces.localdev.me" }
  let(:workspaces_per_user_quota) { 20 }
  let(:workspaces_quota) { 100 }
  let(:user) { create(:user, name: "Workspaces User", email: "workspaces-user@example.org") }
  let(:current_user) { user }
  let(:common_parent_namespace_name) { "common-parent-group" }
  let(:common_parent_namespace) { create(:group, name: common_parent_namespace_name, owners: agent_admin_user) }
  let(:common_organization) { common_parent_namespace.organization }
  let(:organization_user) { create(:user, organization: common_organization) }

  let(:agent_project_namespace) do
    create(:group, name: "agent-project-group", parent: common_parent_namespace)
  end

  let(:workspace_project_namespace_name) { "project-group" }
  let(:workspace_project_namespace) do
    create(:group, name: workspace_project_namespace_name, parent: common_parent_namespace)
  end

  let(:workspace_project_name) { "project" }
  let(:workspace_namespace_path) { "#{common_parent_namespace_name}/#{workspace_project_namespace_name}" }
  let(:project_ref) { "master" }
  let(:devfile_path) { ".devfile.yaml" }
  let(:devfile_fixture_name) { "example.devfile.yaml.erb" }
  let(:devfile_yaml) do
    read_devfile_yaml(
      devfile_fixture_name,
      namespace_path: workspace_namespace_path,
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile_yaml) do
    example_processed_devfile_yaml(
      namespace_path: workspace_namespace_path,
      project_name: workspace_project_name
    )
  end

  let(:expected_processed_devfile) { yaml_safe_load_symbolized(expected_processed_devfile_yaml) }
  let(:user_provided_variables) do
    [
      { key: "VAR1", value: "value 1", type: :environment },
      { key: "VAR2", value: "value 2", type: :environment }
    ]
  end

  let(:user_defined_commands) do
    [
      {
        id: "db-component-command-with-working-dir",
        exec: {
          component: "database-container",
          commandLine: "echo 'executes postStart command in the specified workingDir'",
          workingDir: "test-dir",
          hotReloadCapable: false
        }
      },
      {
        id: "db-component-command-without-working-dir",
        exec: {
          component: "database-container",
          commandLine: "echo 'executes postStart command in the the container's default WORKDIR'",
          hotReloadCapable: false
        }
      },
      {
        id: "main-component-command-without-working-dir",
        exec: {
          component: "tooling-container",
          commandLine: "echo 'executes postStart command in the projects/project_path directory'",
          hotReloadCapable: false
        }
      },
      {
        id: "user-defined-command",
        exec: {
          component: "tooling-container",
          commandLine: "echo 'executes postStart command in the specified workingDir'",
          workingDir: "test-dir",
          hotReloadCapable: false
        }
      }
    ]
  end

  let(:namespace_agents_config_query) do
    <<~GRAPHQL
      query {
          namespace(fullPath: "#{common_parent_namespace.full_path}") {
            workspacesClusterAgents(filter: AVAILABLE) {
              nodes {
                id
                workspacesAgentConfig {
                  id
                  projectId
                  enabled
                  gitlabWorkspacesProxyNamespace
                  networkPolicyEnabled
                  dnsZone
                  workspacesPerUserQuota
                  workspacesQuota
                }
              }
            }
          }
        }
    GRAPHQL
  end

  let(:workspace_project) do
    files = { devfile_path => devfile_yaml }
    create(:project, :in_group, :custom_repo, path: workspace_project_name, files: files,
      namespace: workspace_project_namespace, developers: [user, organization_user])
  end

  let(:image_pull_secrets) { [{ name: 'secret-name', namespace: 'secret-namespace' }] }

  let(:agent_config_file_hash) do
    {
      remote_development: {
        enabled: true,
        dns_zone: dns_zone,
        workspaces_per_user_quota: workspaces_per_user_quota,
        workspaces_quota: workspaces_quota,
        image_pull_secrets: image_pull_secrets
      }
    }
  end

  let(:agent_project) do
    create(:project, :in_group, path: "agent-project", namespace: agent_project_namespace, developers: user)
  end

  let(:agent) do
    create(:ee_cluster_agent, project: agent_project, created_by_user: agent_admin_user, project_id: agent_project.id)
  end

  # @param [String] random_string
  # @param [User, QA::Resource::User] user
  # @return [Array]
  def expected_internal_variables(random_string:, user:)
    # rubocop:disable Layout/LineLength -- keep them on one line for easier readability and editability
    [
      { key: "GL_WORKSPACE_LOGS_DIR", type: :environment, value: workspace_operations_constants_module::WORKSPACE_LOGS_DIR },
      { key: create_constants_module::TOKEN_FILE_NAME, type: :file, value: /glpat-.+/ },
      { key: "GL_TOKEN_FILE_PATH", type: :environment, value: token_file_path },
      { key: git_credential_store_script_file_name, type: :file, value: git_credential_store_script },
      { key: "GIT_CONFIG_COUNT", type: :environment, value: "3" },
      { key: "GIT_CONFIG_KEY_0", type: :environment, value: "credential.helper" },
      { key: "GIT_CONFIG_KEY_1", type: :environment, value: "user.name" },
      { key: "GIT_CONFIG_KEY_2", type: :environment, value: "user.email" },
      { key: "GIT_CONFIG_VALUE_0", type: :environment, value: git_credential_store_script_file_path },
      { key: "GIT_CONFIG_VALUE_1", type: :environment, value: user.name },
      { key: "GIT_CONFIG_VALUE_2", type: :environment, value: user.email },
      { key: "gl_agentw_token", type: :file, value: agentw_token },
      { key: "GL_AGENTW_TOKEN_FILE_PATH", type: :environment, value: agentw_token_file_path },
      { key: "GL_AGENTW_OBSERVABILITY_LISTEN_ADDRESS", type: :environment, value: agentw_observability_listen_address },
      { key: "GL_GITLAB_AGENT_SERVER_ADDRESS", type: :environment, value: gitlab_kas_external_url },
      { key: "GL_VSCODE_EXTENSION_MARKETPLACE_ITEM_URL", type: :environment, value: "https://open-vsx.org/vscode/item" },
      { key: "GL_VSCODE_EXTENSION_MARKETPLACE_RESOURCE_URL_TEMPLATE", type: :environment, value: "https://open-vsx.org/vscode/unpkg/{publisher}/{name}/{versionRaw}/{path}" },
      { key: "GL_VSCODE_EXTENSION_MARKETPLACE_SERVICE_URL", type: :environment, value: "https://open-vsx.org/vscode/gallery" },
      { key: "GL_WORKSPACE_DOMAIN_TEMPLATE", type: :environment, value: "${PORT}-#{random_string}.#{dns_zone}" },
      { key: "GITLAB_WORKFLOW_INSTANCE_URL", type: :environment, value: Gitlab::Routing.url_helpers.root_url },
      { key: "GITLAB_WORKFLOW_TOKEN_FILE", type: :environment, value: token_file_path }
    ]
    # rubocop:enable Layout/LineLength
  end

  # @return [String]
  def kas_jwt_token
    JWT.encode(
      { "iss" => Gitlab::Kas::JWT_ISSUER, 'aud' => Gitlab::Kas::JWT_AUDIENCE },
      Gitlab::Kas.secret,
      "HS256"
    )
  end

  # @return [void]
  def do_get_internal_agents_agentw_server_config
    # Perform an /internal/agents/agentw/server_config GET which will cause a workspaces oauth application to be created

    params = {} # No params currently for this endpoint

    agent_token_headers = {
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => kas_jwt_token
    }
    server_config_url = api("/internal/agents/agentw/server_config")

    allow_next_instance_of(Grape::Request) do |request|
      allow(request).to receive(:remote_ip).and_return("1.1.1.1")
    end

    get server_config_url, params: params, headers: agent_token_headers, as: :json

    expect(response).to have_gitlab_http_status(:ok)

    expect(::Gitlab::CurrentSettings.current_application_settings.workspaces_oauth_application).not_to be_nil

    workspaces_oauth_application =
      ::Gitlab::CurrentSettings.current_application_settings.workspaces_oauth_application || raise

    generator_module = RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator
    expect(json_response.symbolize_keys).to eq(
      {
        api_external_url:
          workspaces_oauth_application.redirect_uri.gsub("/#{generator_module::OAUTH_REDIRECT_URI_PATH_SEGMENT}", ""),
        oauth_client_id: workspaces_oauth_application.uid,
        oauth_redirect_url: workspaces_oauth_application.redirect_uri
      }
    )

    nil
  end

  # @param [RemoteDevelopment::Workspace] workspace
  # @return [void]
  def do_get_internal_agents_agentw_agent_info(workspace:)
    # Perform an /internal/agents/agentw/agent_info GET which will authenticate with the workspace_token
    # and return the workspace's id.

    workspace_token_string = workspace.workspace_token.token
    expect(workspace_token_string).to match(/#{::RemoteDevelopment::WorkspaceToken::TOKEN_PREFIX}.+/o)

    params = {} # No params currently for this endpoint

    headers = {
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => kas_jwt_token,
      Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => workspace_token_string
    }
    agent_info_url = api("/internal/agents/agentw/agent_info")

    get agent_info_url, params: params, headers: headers, as: :json

    expect(response).to have_gitlab_http_status(:ok)

    expect(json_response.symbolize_keys).to eq(
      {
        workspace_id: workspace.id
      }
    )

    nil
  end

  # @param [RemoteDevelopment::Workspace] workspace
  # @param [User] user
  # @return [void]
  def do_get_internal_agents_agentw_authorize_user_access(workspace:, user:)
    # Perform an /internal/agents/agentw/authorize_user_access GET which will check if the user
    # is authorized to access the workspace based on the workspace host and user ID.

    # Extract the host from the workspace URL instead of manually constructing it
    workspace_host = URI.parse(workspace.url).host

    params = {
      workspace_host: workspace_host,
      user_id: user.id
    }

    headers = {
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => kas_jwt_token
    }
    authorize_user_access_url = api("/internal/agents/agentw/authorize_user_access")

    get authorize_user_access_url, params: params, headers: headers

    expect(response).to have_gitlab_http_status(:ok)

    expected_status = ::RemoteDevelopment::WorkspacesServerOperations::AuthorizeUserAccess::Status::AUTHORIZED
    expect(json_response).to eq(
      {
        "status" => expected_status,
        "info" => {
          "port" => ::RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::WORKSPACE_EDITOR_PORT.to_s,
          "workspace_id" => workspace.id
        }
      }
    )

    nil
  end

  # @return [void]
  def do_create_workspaces_agent_config
    # Perform an agent update post which will cause a workspaces_agent_config record to be created
    # based on the cluster agent's config file.

    params = {
      agent_id: agent.id,
      agent_config: agent_config_file_hash
    }

    agent_token_headers = {
      Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => agent_token.token,
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => kas_jwt_token
    }
    agent_configuration_url = api("/internal/kubernetes/agent_configuration", personal_access_token: agent_token)

    post agent_configuration_url, params: params, headers: agent_token_headers, as: :json

    # The internal kubernetes agent_configuration API endpoint does not return any response,
    # it only returns 204 No Content.
    expect(response).to have_gitlab_http_status(:no_content)

    workspaces_agent_config = RemoteDevelopment::WorkspacesAgentConfig.find_by_cluster_agent_id!(agent.id)

    # Get the agent config via the GraphQL API to verify it was created correctly
    get_graphql(namespace_agents_config_query, current_user: agent_admin_user)
    expected_agent_config =
      {
        "id" => "gid://gitlab/RemoteDevelopment::WorkspacesAgentConfig/#{workspaces_agent_config.id}",
        "projectId" => agent_project.id.to_s,
        "enabled" => true,
        "gitlabWorkspacesProxyNamespace" => "gitlab-workspaces",
        "networkPolicyEnabled" => true,
        "dnsZone" => dns_zone,
        "workspacesPerUserQuota" => workspaces_per_user_quota,
        "workspacesQuota" => workspaces_quota
      }
    expect(
      graphql_data_at(:namespace, :workspacesClusterAgents, :nodes, 0, :workspacesAgentConfig)
    ).to eq(expected_agent_config)

    nil
  end

  # @return [void]
  def do_create_namespace_mapping
    namespace_create_remote_development_cluster_agent_mapping_create_mutation_args =
      {
        namespace_id: common_parent_namespace.to_global_id.to_s,
        cluster_agent_id: agent.to_global_id.to_s
      }
    do_graphql_mutation_post(
      name: :namespace_create_remote_development_cluster_agent_mapping,
      input: namespace_create_remote_development_cluster_agent_mapping_create_mutation_args,
      user: agent_admin_user
    )

    nil
  end

  # @return [void]
  def do_delete_namespace_mapping
    namespace_delete_remote_development_cluster_agent_mapping_delete_mutation_args =
      {
        namespace_id: common_parent_namespace.to_global_id.to_s,
        cluster_agent_id: agent.to_global_id.to_s
      }
    do_graphql_mutation_post(
      name: :namespace_delete_remote_development_cluster_agent_mapping,
      input: namespace_delete_remote_development_cluster_agent_mapping_delete_mutation_args,
      user: agent_admin_user
    )

    nil
  end

  # @return [void]
  def do_create_org_mapping
    organization_create_cluster_agent_mapping_create_mutation_args =
      {
        organization_id: common_organization.to_global_id.to_s,
        cluster_agent_id: agent.to_global_id.to_s
      }
    # noinspection RubyMismatchedArgumentType -- RubyMine is not detecting that FactoryBot returns a User type
    do_graphql_mutation_post(
      name: :organization_create_cluster_agent_mapping,
      input: organization_create_cluster_agent_mapping_create_mutation_args,
      user: create(:user, owner_of: common_organization)
    )

    nil
  end

  # rubocop:disable Metrics/AbcSize -- We want this to stay a single method
  # @param [Array<String>] workspace_name_parts
  # @param [User, QA::Resource::User] user
  # @return [RemoteDevelopment::Workspace]
  def do_create_workspace(workspace_name_parts:, user:)
    allow(FFaker::Food).to receive(:fruit).and_return(workspace_name_parts[0])
    allow(FFaker::AnimalUS).to receive(:common_name).and_return(workspace_name_parts[1])
    allow(FFaker::Color).to receive(:name).and_return(workspace_name_parts[2])

    random_string = workspace_name_parts
                      .map { |name_segment| name_segment.parameterize(separator: "") }
                      .join("-").parameterize.downcase

    # FETCH THE AGENT CONFIG VIA THE GRAPHQL API, SO WE CAN USE ITS VALUES WHEN CREATING WORKSPACE
    cluster_agent_gid = "gid://gitlab/Clusters::Agent/#{agent.id}"

    create_mutation_response = do_graphql_mutation_post(
      name: :workspace_create,
      input: workspace_create_mutation_args(cluster_agent_gid),
      user: user
    )

    workspace_gid = create_mutation_response.fetch("workspace").fetch("id")
    workspace_id = GitlabSchema.parse_gid(workspace_gid, expected_type: ::RemoteDevelopment::Workspace)&.model_id
    workspace = ::RemoteDevelopment::Workspace.find(workspace_id)

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    expect(workspace.user).to eq(user)
    expect(workspace.agent).to eq(agent)
    # noinspection RubyResolve
    expect(workspace.desired_state_updated_at).to eq(Time.current)
    expect(workspace.name).to eq(random_string)
    namespace_prefix = create_constants_module::NAMESPACE_PREFIX
    expect(workspace.namespace).to eq("#{namespace_prefix}-#{random_string}")
    expect(workspace.url).to eq(URI::HTTPS.build({
      host: "#{create_constants_module::WORKSPACE_EDITOR_PORT}-#{workspace.name}.#{dns_zone}",
      path: "/",
      query: {
        folder: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/#{workspace_project.path}"
      }.to_query
    }).to_s)
    # noinspection RubyResolve
    expect(workspace.devfile).to eq(devfile_yaml)
    actual_processed_devfile = yaml_safe_load_symbolized(workspace.processed_devfile)
    expect(actual_processed_devfile.fetch(:components)).to eq(expected_processed_devfile.fetch(:components))
    expect(actual_processed_devfile).to eq(expected_processed_devfile)

    all_expected_vars =
      (expected_internal_variables(random_string: random_string, user: user) + user_provided_variables)
        .sort_by { |v| v[:key] }

    # NOTE: We convert the actual records into hashes and sort them as a hash rather than ordering in
    #       ActiveRecord, to account for platform- or db-specific sorting differences.
    types = RemoteDevelopment::Enums::WorkspaceVariable::WORKSPACE_VARIABLE_TYPES
    all_actual_vars = RemoteDevelopment::WorkspaceVariable.where(workspace: workspace)

    # noinspection RailsParamDefResolve -- RubyMine is incorrectly detecting this as ActiveRecord #select method
    # noinspection RubyArgCount -- RubyMine is incorrectly detecting this as an unused block argument
    actual_user_provided_vars = all_actual_vars.select(&:user_provided).sort_by(&:key)

    all_actual_vars = all_actual_vars.map { |v| { key: v.key, type: types.invert[v.variable_type], value: v.value } }
                                     .sort_by { |v| v[:key] }

    # Check that user provided variables had their flag set correctly.
    expect(actual_user_provided_vars.count).to eq(user_provided_variables.count)
    expect(actual_user_provided_vars[0][:key]).to eq(user_provided_variables[0][:key])

    # Check just keys first, to get an easy failure message if a new key has been added
    expect(all_actual_vars.pluck(:key)).to match_array(all_expected_vars.pluck(:key))

    # Then check the full attributes for all vars except gl_token, which must be compared as a regex
    expected_without_regexes = all_expected_vars.reject { |v| v[:key] == token_file_name }
    actual_without_regexes = all_actual_vars.reject { |v| v[:key] == token_file_name }
    expect(expected_without_regexes).to match(actual_without_regexes)

    expected_gl_token_value =
      expected_internal_variables(random_string: random_string,
        user: user).find { |var| var[:key] == token_file_name }[:value]
    actual_gl_token_value = all_actual_vars.find { |var| var[:key] == token_file_name }[:value]
    expect(actual_gl_token_value).to match(expected_gl_token_value)

    workspace
  end

  # rubocop:enable Metrics/AbcSize

  # @param [String] cluster_agent_gid
  # @return [Hash]
  def workspace_create_mutation_args(cluster_agent_gid)
    {
      desired_state: states::RUNNING,
      editor: "webide",
      cluster_agent_id: cluster_agent_gid,
      project_id: workspace_project.to_global_id.to_s,
      project_ref: project_ref,
      devfile_path: devfile_path,
      variables: user_provided_variables.each_with_object([]) do |variable, arr|
        arr << variable.merge(type: variable[:type].to_s.upcase)
      end
    }
  end

  # @param [RemoteDevelopment::Workspace] workspace
  # @return [void]
  def do_start_workspace(workspace)
    do_change_workspace_state(workspace: workspace, desired_state: states::RUNNING)

    nil
  end

  # @param [RemoteDevelopment::Workspace] workspace
  # @return [void]
  def do_stop_workspace(workspace)
    do_change_workspace_state(workspace: workspace, desired_state: states::STOPPED)

    nil
  end

  # @param [RemoteDevelopment::Workspace] workspace
  # @param [String] desired_state
  # @return [void]
  def do_change_workspace_state(workspace:, desired_state:)
    workspace_update_mutation_args = {
      id: global_id_of(workspace),
      desired_state: desired_state
    }

    do_graphql_mutation_post(
      name: :workspace_update,
      input: workspace_update_mutation_args,
      user: user
    )

    # NOTE: Where possible, avoid explicit assertions here and replace them with assertions on the
    #       response_json data sent in the reconciliation loop "simulate_N_poll" methods.

    # noinspection RubyResolve
    expect(workspace.reload.desired_state_updated_at).to eq(Time.current)

    nil
  end

  # @param [Symbol] name
  # @param [Hash] input
  # @param [User, QA::Resource::User] user
  # @return [Hash]
  def do_graphql_mutation_post(name:, input:, user:)
    mutation = graphql_mutation(name, input)
    post_graphql_mutation(mutation, current_user: user)
    expect_graphql_errors_to_be_empty
    mutation_response = graphql_mutation_response(name)
    expect(mutation_response.fetch("errors")).to eq([])
    mutation_response
  end

  # @param [Hash] params
  # @param [QA::Resource::Clusters::AgentToken] agent_token
  # @return [Hash] response_json with deep symbolized keys
  def do_reconcile_post(params:, agent_token:)
    # Custom logic to perform the reconcile post for a _REQUEST_ spec

    agent_token_headers = {
      Gitlab::Kas::INTERNAL_API_AGENT_REQUEST_HEADER => agent_token.token,
      Gitlab::Kas::INTERNAL_API_KAS_REQUEST_HEADER => kas_jwt_token
    }
    reconcile_url = api("/internal/kubernetes/modules/remote_development/reconcile", personal_access_token: agent_token)

    post reconcile_url, params: params, headers: agent_token_headers, as: :json

    expect(response).to have_gitlab_http_status(:created)
    json_response.deep_symbolize_keys
  end

  shared_examples 'workspace lifecycle' do
    before do
      stub_licensed_features(remote_development: true)

      allow(Gitlab::Kas).to receive(:secret).and_return(jwt_secret)

      allow(workspace_project.repository).to receive_message_chain(:blob_at_branch, :data) { devfile_yaml }
    end

    it "successfully exercises the full lifecycle of a workspace", :unlimited_max_formatted_output_length do # rubocop:disable RSpec/NoExpectationExample -- the expectations are in the called methods
      # KAS INTERNAL REQUEST: CREATE THE WORKSPACES OAUTH APP AND GET THE AGENTW SERVER CONFIG VIA REST API
      do_get_internal_agents_agentw_server_config

      # CREATE THE NamespaceClusterAgentMapping VIA GRAPHQL API
      do_create_namespace_mapping

      # CREATE THE WorkspacesAgentConfig VIA REST and GRAPHQL APIs
      do_create_workspaces_agent_config

      # CREATE WORKSPACE VIA GRAPHQL API
      workspace = do_create_workspace(workspace_name_parts: %w[Date Butterfly Darkturquoise], user: user)

      additional_args_for_expected_config_to_apply =
        build_additional_args_for_expected_config_to_apply_yaml_stream(
          network_policy_enabled: true,
          dns_zone: dns_zone,
          namespace_path: workspace_project_namespace.full_path,
          project_name: workspace_project_name,
          image_pull_secrets: image_pull_secrets,
          user_defined_commands: user_defined_commands
        )

      # AGENTW INTERNAL REQUEST: GET THE AGENTW AGENT INFO VIA REST API
      do_get_internal_agents_agentw_agent_info(workspace: workspace)

      # KAS INTERNAL REQUEST: AUTHORIZE USER ACCESS VIA REST API
      do_get_internal_agents_agentw_authorize_user_access(workspace: workspace, user: user)

      # SIMULATE RECONCILE RESPONSE TO AGENTK SENDING NEW WORKSPACE
      simulate_first_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::CREATION_REQUESTED,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO RUNNING ACTUAL_STATE
      simulate_second_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::RUNNING,
        **additional_args_for_expected_config_to_apply
      )

      # UPDATE WORKSPACE DESIRED_STATE TO STOPPED VIA GRAPHQL API
      do_stop_workspace(workspace)

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE
      simulate_third_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::RUNNING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE
      simulate_fourth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::STOPPING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE
      simulate_fifth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::STOPPED,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR PARTIAL RECONCILE TO SHOW NO RAILS_INFOS ARE SENT
      simulate_sixth_poll(agent_token: agent_token)

      # SIMULATE RECONCILE RESPONSE TO AGENTK FOR FULL RECONCILE TO SHOW ALL WORKSPACES ARE SENT IN RAILS_INFOS
      simulate_seventh_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::STOPPED,
        **additional_args_for_expected_config_to_apply
      )

      # UPDATE WORKSPACE DESIRED_STATE BACK TO RUNNING VIA GRAPHQL API
      do_start_workspace(workspace)

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO RUNNING DESIRED_STATE
      simulate_eighth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::STOPPED,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE TRAVEL FORWARD IN TIME MAX_ACTIVE_HOURS_BEFORE_STOP HOURS
      simulate_ninth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::RUNNING,
        time_to_travel_after_poll: workspace.workspaces_agent_config.max_active_hours_before_stop.hours,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO STOPPED DESIRED_STATE
      simulate_tenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::RUNNING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPING ACTUAL_STATE
      simulate_eleventh_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::STOPPING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO STOPPED ACTUAL_STATE
      simulate_twelfth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::STOPPED,
        # TRAVEL FORWARD IN TIME MAX_STOPPED_HOURS_BEFORE_TERMINATION HOURS
        time_to_travel_after_poll: workspace.workspaces_agent_config.max_stopped_hours_before_termination.hours,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE RESPONSE TO AGENTK UPDATING WORKSPACE TO TERMINATED DESIRED_STATE
      simulate_thirteenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::TERMINATED,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO TERMINATING ACTUAL_STATE
      simulate_fourteenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        actual_state: states::TERMINATING,
        **additional_args_for_expected_config_to_apply
      )

      # SIMULATE RECONCILE REQUEST FROM AGENTK UPDATING WORKSPACE TO TERMINATED ACTUAL_STATE
      simulate_fifteenth_poll(
        workspace: workspace.reload,
        agent_token: agent_token,
        **additional_args_for_expected_config_to_apply
      )

      # DELETE NAMESPACE AGENT MAPPING, AND CREATE ORGANIZATION MAPPING
      do_delete_namespace_mapping
      do_create_org_mapping

      # CREATE A NEW WORKSPACE WITH THE ORGANIZATION MAPPING WITH MINIMUM USER PRIVILEGES
      do_create_workspace(workspace_name_parts: ["Peach", "Blue Whale", "Red"], user: organization_user)
    end
  end

  describe "a happy path workspace lifecycle" do
    # NOTE: Even though this is only called once, we leave it as a shared example, so that we can easily
    #       introduce additional contexts with different behavior for temporary feature flag testing.
    it_behaves_like 'workspace lifecycle'
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
