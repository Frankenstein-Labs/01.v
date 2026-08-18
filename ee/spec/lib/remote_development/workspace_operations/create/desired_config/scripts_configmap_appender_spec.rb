# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::ScriptsConfigmapAppender, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:files) { RemoteDevelopment::Files }
  let(:annotations) { { a: "1" } }
  let(:labels) { { b: "2" } }
  let(:name) { "workspacename-scripts-configmap" }
  let(:namespace) { "namespace" }
  let(:processed_devfile) { example_processed_devfile }
  let(:devfile_commands) { processed_devfile.fetch(:commands) }
  let(:devfile_events) { processed_devfile.fetch(:events) }
  let(:user_defined_poststart_commands) do
    extract_user_defined_poststart_commands(devfile_commands: devfile_commands, devfile_events: devfile_events)
  end

  subject(:updated_desired_config) do
    # Make a fake desired config with one existing fake element, to prove we are appending
    desired_config_array = [
      {}
    ]

    described_class.append(
      desired_config_array: desired_config_array,
      name: name,
      namespace: namespace,
      project_path: "test-project",
      labels: labels,
      annotations: annotations,
      devfile_commands: devfile_commands,
      devfile_events: devfile_events,
      processed_devfile: processed_devfile
    )

    desired_config_array
  end

  it "appends ConfigMap to desired_config_array" do
    expect(updated_desired_config.length).to eq(2)

    updated_desired_config => [
      {}, # existing fake element
      {
        apiVersion: api_version,
        metadata: {
          name: configmap_name
        },
        data: data
      },
    ]

    db_container_non_blocking_script_name =
      "database-container-#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}"

    main_container_non_blocking_script_name =
      "tooling-container-#{create_constants_module::RUN_NON_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}"

    expect(api_version).to eq("v1")
    expect(configmap_name).to eq(name)
    expect(data).to eq(
      "gl-clone-project-command": clone_project_script,
      "gl-clone-unshallow-command": clone_unshallow_script,
      "gl-init-tools-command": format(files::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT,
        main_component_name: Shellwords.shellescape("tooling-container")),
      "gl-start-sshd-command": format(files::INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT,
        main_component_name: Shellwords.shellescape("tooling-container")),
      "tooling-container-#{create_constants_module::RUN_INTERNAL_BLOCKING_POSTSTART_COMMANDS_SCRIPT_NAME}":
        internal_blocking_poststart_commands_script,
      main_container_non_blocking_script_name.to_sym =>
        non_blocking_poststart_commands_script(
          poststart_commands: user_defined_poststart_commands
        ),
      db_container_non_blocking_script_name.to_sym =>
        non_blocking_poststart_commands_script(
          poststart_commands: user_defined_poststart_commands,
          component_name: "database-container"
        ),
      "gl-sleep-until-container-is-running-command":
        sleep_until_container_is_running_script,
      "db-component-command-with-working-dir": "echo 'executes postStart command in the specified workingDir'",
      "db-component-command-without-working-dir":
        "echo 'executes postStart command in the the container's default WORKDIR'",
      "main-component-command-without-working-dir":
        "echo 'executes postStart command in the projects/project_path directory'",
      "user-defined-command": "echo 'executes postStart command in the specified workingDir'"
    )

    db_non_blocking_script = data[db_container_non_blocking_script_name.to_sym]
    main_non_blocking_script = data[main_container_non_blocking_script_name.to_sym]

    expect(db_non_blocking_script).to include(
      '(cd test-dir && /workspace-scripts/database-container/db-component-command-with-working-dir) || true'
    )
    expect(db_non_blocking_script).to include(
      '/workspace-scripts/database-container/db-component-command-without-working-dir || true'
    )
    expect(main_non_blocking_script).to include(
      '(cd ${PROJECT_SOURCE}/test-project && ' \
        '/workspace-scripts/tooling-container/main-component-command-without-working-dir) || true'
    )
    expect(main_non_blocking_script).to include(
      '(cd test-dir && /workspace-scripts/tooling-container/user-defined-command) || true'
    )
  end

  context "when legacy poststart scripts are used" do
    let(:processed_devfile) do
      yaml_safe_load_symbolized(
        read_devfile_yaml("example.legacy-poststart-in-container-command-processed-devfile.yaml.erb",
          is_legacy_poststart: true
        )
      )
    end

    it "appends ConfigMap to desired_config_array" do
      expect(updated_desired_config.length).to eq(2)

      updated_desired_config => [
        {}, # existing fake element
        {
          apiVersion: api_version,
          metadata: {
            name: configmap_name
          },
          data: data
        },
      ]

      expect(api_version).to eq("v1")
      expect(configmap_name).to eq(name)
      expect(data).to eq(
        "gl-clone-project-command": clone_project_script,
        "gl-init-tools-command": files::INTERNAL_POSTSTART_COMMAND_START_VSCODE_SCRIPT,
        create_constants_module::LEGACY_RUN_POSTSTART_COMMANDS_SCRIPT_NAME.to_sym =>
          legacy_poststart_commands_script,
        "gl-sleep-until-container-is-running-command":
          sleep_until_container_is_running_script,
        "gl-start-sshd-command": files::INTERNAL_POSTSTART_COMMAND_START_SSHD_SCRIPT
      )
    end
  end
end
