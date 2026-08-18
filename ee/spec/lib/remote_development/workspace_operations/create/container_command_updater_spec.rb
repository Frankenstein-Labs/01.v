# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::ContainerCommandUpdater, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile) do
    read_devfile("example.main-container-updated-devfile.yaml.erb")
  end

  let(:expected_processed_devfile_name) { "example.container-commands-updated-devfile.yaml.erb" }
  let(:expected_processed_devfile) { read_devfile(expected_processed_devfile_name) }

  let(:vscode_extension_marketplace_metadata_enabled) { false }

  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      tools_dir: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
        "#{create_constants_module::TOOLS_DIR_NAME}",
      vscode_extension_marketplace_metadata: { enabled: vscode_extension_marketplace_metadata_enabled }
    }
  end

  subject(:returned_value) do
    described_class.update(context) # rubocop:disable Rails/SaveBang -- Silly rubocop, this isn't an ActiveRecord object
  end

  it 'preserves script formatting' do
    expected = expected_processed_devfile[:components].first[:container][:args].first
    actual = returned_value[:processed_devfile][:components].first[:container][:args].first
    expect(actual).to eq(expected)
  end

  it "adds the overrideCommand attribute for components when not specified in the devfile" do
    result = returned_value[:processed_devfile]
    components = result[:components]

    # Find the main component
    main_component = components.find { |c| c[:name] == "tooling-container" }
    expect(main_component[:attributes][:overrideCommand]).to be true

    # Find non-main components that don't already have overrideCommand set
    database_component = components.find { |c| c[:name] == "database-container" }
    expect(database_component[:attributes][:overrideCommand]).to be false

    tools_injector_component = components.find { |c| c[:name] == "gl-tools-injector" }
    expect(tools_injector_component[:attributes][:overrideCommand]).to be false

    # Verify that existing overrideCommand values are preserved
    user_defined_component = components.find { |c| c[:name] == "user-defined-entrypoint-cmd-component" }
    expect(user_defined_component[:attributes][:overrideCommand]).to be false
  end

  it "updates container command and args for components with overrideCommand: true" do
    result = returned_value[:processed_devfile]
    components = result[:components]

    # Main component should have its command and args updated
    main_component = components.find { |c| c[:name] == "tooling-container" }
    expect(main_component[:container][:command]).to eq(%w[/bin/sh -c])
    expect(main_component[:container][:args]).to eq([files_module::CONTAINER_KEEPALIVE_COMMAND_ARGS])

    # Non-main components should not have their command/args updated
    database_component = components.find { |c| c[:name] == "database-container" }
    expect(database_component[:container]).not_to have_key(:command)
    expect(database_component[:container]).not_to have_key(:args)
  end
end
