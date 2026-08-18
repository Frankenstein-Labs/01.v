# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::MainComponentUpdater, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile) do
    read_devfile("example.tools-injector-inserted-devfile.yaml.erb")
  end

  let(:expected_processed_devfile_name) { "example.main-container-updated-devfile.yaml.erb" }
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

  it 'updates the main component' do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end

  context "when vscode_extension_marketplace_metadata Web IDE setting is disabled" do
    let(:expected_processed_devfile_name) { "example.main-container-updated-marketplace-disabled-devfile.yaml.erb" }
    let(:vscode_extension_marketplace_metadata_enabled) { false }

    it 'injects the tools injector component' do
      expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
    end
  end
end
