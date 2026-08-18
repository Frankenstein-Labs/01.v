# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::ToolsInjectorComponentInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile) do
    read_devfile("example.flattened-devfile.yaml.erb")
  end

  let(:expected_processed_devfile) do
    read_devfile("example.tools-injector-inserted-devfile.yaml.erb")
  end

  let(:tools_injector_image_from_settings) do
    workspace_operations_constants_module::WORKSPACE_TOOLS_IMAGE
  end

  let(:settings) do
    {
      tools_injector_image: tools_injector_image_from_settings
    }
  end

  let(:vscode_extension_marketplace_metadata_enabled) { false }

  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      tools_dir: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
        "#{create_constants_module::TOOLS_DIR_NAME}",
      settings: settings,
      vscode_extension_marketplace_metadata: { enabled: vscode_extension_marketplace_metadata_enabled }
    }
  end

  subject(:returned_value) do
    described_class.insert(context)
  end

  it 'inserts the tools injector component' do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end

  context 'when image is overridden in settings' do
    let(:tools_injector_image_from_settings) { 'my/awesome/image:42' }

    it 'uses image override' do
      components = returned_value.dig(:processed_devfile, :components)
      gl_tools_component = components.find do |component|
        component[:name] == create_constants_module::TOOLS_INJECTOR_COMPONENT_NAME
      end
      image_from_processed_devfile = gl_tools_component.dig(:container, :image)

      expect(image_from_processed_devfile).to eq(tools_injector_image_from_settings)
    end
  end
end
