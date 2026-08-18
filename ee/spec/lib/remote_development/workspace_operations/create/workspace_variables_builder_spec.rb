# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesBuilder, feature_category: :workspaces do
  include_context "with constant modules"

  let(:domain_template) { "${PORT}-name.example.host.suffix" }
  let(:gitlab_kas_external_url) { "ws://kas.example.com/-/external/namespace/path" }
  let(:personal_access_token_value) { "example-pat-value" }
  let(:user_name) { "example.user.name" }
  let(:user_email) { "example@user.email" }
  let(:workspace_id) { 1 }
  let(:workspace_token) { "example-agentw-token-value" }
  let(:vscode_extensions_gallery_service_url) { "https://open-vsx.org/vscode/gallery" }
  let(:vscode_extensions_gallery_item_url) { "https://open-vsx.org/vscode/item" }
  let(:vscode_extensions_gallery_resource_url_template) { "https://open-vsx.org/vscode/unpkg/{publisher}/{name}/{versionRaw}/{path}" }
  let(:git_credential_store_script) { RemoteDevelopment::Files::GIT_CREDENTIAL_STORE_SCRIPT }
  let(:expected_variables) do
    [
      {
        key: "GL_WORKSPACE_LOGS_DIR",
        value: RemoteDevelopment::WorkspaceOperations::WorkspaceOperationsConstants::WORKSPACE_LOGS_DIR,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: create_constants_module::TOKEN_FILE_NAME,
        value: "example-pat-value",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::FILE_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_TOKEN_FILE_PATH",
        value: create_constants_module::TOKEN_FILE_PATH,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: create_constants_module::GIT_CREDENTIAL_STORE_SCRIPT_FILE_NAME,
        value: git_credential_store_script,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::FILE_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GIT_CONFIG_COUNT",
        value: "3",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GIT_CONFIG_KEY_0",
        value: "credential.helper",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GIT_CONFIG_VALUE_0",
        value: create_constants_module::GIT_CREDENTIAL_STORE_SCRIPT_FILE_PATH,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GIT_CONFIG_KEY_1",
        value: "user.name",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GIT_CONFIG_VALUE_1",
        value: "example.user.name",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GIT_CONFIG_KEY_2",
        value: "user.email",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GIT_CONFIG_VALUE_2",
        value: "example@user.email",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_WORKSPACE_DOMAIN_TEMPLATE",
        value: domain_template,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_VSCODE_EXTENSION_MARKETPLACE_SERVICE_URL",
        value: vscode_extensions_gallery_service_url,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_VSCODE_EXTENSION_MARKETPLACE_ITEM_URL",
        value: vscode_extensions_gallery_item_url,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_VSCODE_EXTENSION_MARKETPLACE_RESOURCE_URL_TEMPLATE",
        value: vscode_extensions_gallery_resource_url_template,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GITLAB_WORKFLOW_INSTANCE_URL",
        value: Gitlab::Routing.url_helpers.root_url,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GITLAB_WORKFLOW_TOKEN_FILE",
        value: create_constants_module::TOKEN_FILE_PATH,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: create_constants_module::AGENTW_TOKEN_FILE_NAME,
        value: "example-agentw-token-value",
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::FILE_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_AGENTW_TOKEN_FILE_PATH",
        value: create_constants_module::AGENTW_TOKEN_FILE_PATH,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_GITLAB_AGENT_SERVER_ADDRESS",
        value: gitlab_kas_external_url,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "GL_AGENTW_OBSERVABILITY_LISTEN_ADDRESS",
        value: create_constants_module::AGENTW_OBSERVABILITY_LISTEN_ADDRESS,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "VAR1",
        value: "value 1",
        user_provided: true,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE,
        workspace_id: workspace_id
      },
      {
        key: "/path/to/file",
        value: "value 2",
        user_provided: true,
        variable_type: RemoteDevelopment::Enums::WorkspaceVariable::FILE_TYPE,
        workspace_id: workspace_id
      }
    ]
  end

  subject(:variables) do
    described_class.build(
      domain_template: domain_template,
      gitlab_kas_external_url: gitlab_kas_external_url,
      personal_access_token_value: personal_access_token_value,
      user_name: user_name,
      user_email: user_email,
      workspace_id: workspace_id,
      workspace_token: workspace_token,
      vscode_extension_marketplace: {
        service_url: vscode_extensions_gallery_service_url,
        item_url: vscode_extensions_gallery_item_url,
        resource_url_template: vscode_extensions_gallery_resource_url_template
      },
      variables: [
        {
          key: "VAR1",
          value: "value 1",
          type: RemoteDevelopment::Enums::WorkspaceVariable::ENVIRONMENT_TYPE
        },
        {
          key: "/path/to/file",
          value: "value 2",
          type: RemoteDevelopment::Enums::WorkspaceVariable::FILE_TYPE
        }
      ]
    )
  end

  before do
    allow(Gitlab::Routing).to receive_message_chain(:url_helpers, :root_url).and_return("https://gitlab.com")
  end

  it "defines correct variables" do
    expect(variables).to eq(expected_variables)
  end
end
