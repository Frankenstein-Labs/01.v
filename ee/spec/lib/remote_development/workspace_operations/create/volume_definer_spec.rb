# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::VolumeDefiner, feature_category: :workspaces do
  include_context "with constant modules"

  let(:context) { { params: 1 } }
  let(:expected_tools_dir) do
    "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
      "#{create_constants_module::TOOLS_DIR_NAME}"
  end

  subject(:returned_value) do
    described_class.define(context)
  end

  it "merges volume mount info to passed context" do
    expect(returned_value).to eq(
      {
        params: 1,
        tools_dir: expected_tools_dir,
        volume_mounts: {
          data_volume: {
            name: create_constants_module::WORKSPACE_DATA_VOLUME_NAME,
            path: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
          }
        }
      }
    )
  end
end
