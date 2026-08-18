# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::VolumeComponentInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile) do
    read_devfile("example.internal-poststart-commands-inserted-devfile.yaml.erb")
  end

  let(:expected_processed_devfile) do
    read_devfile("example.processed-devfile.yaml.erb")
  end

  let(:volume_name) { create_constants_module::WORKSPACE_DATA_VOLUME_NAME }
  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      volume_mounts: {
        data_volume: {
          name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME,
          path: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
        }
      }
    }
  end

  subject(:returned_value) do
    described_class.insert(context)
  end

  it "injects the workspace volume component" do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end
end
