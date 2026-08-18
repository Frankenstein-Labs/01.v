# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::ScriptsVolumeInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:name) { "workspacename-scripts-configmap" }
  let(:processed_devfile) { example_processed_devfile }
  let(:devfile_commands) { processed_devfile.fetch(:commands) }
  let(:devfile_events) { processed_devfile.fetch(:events) }
  let(:input_containers) do
    [
      { volumeMounts: [{}] },
      { volumeMounts: [{}] }
    ]
  end

  let(:input_volumes) { [{}] }

  subject(:invoke_insert) do
    described_class.insert(
      configmap_name: name,
      containers: input_containers,
      volumes: input_volumes,
      devfile_commands: devfile_commands,
      devfile_events: devfile_events,
      processed_devfile: processed_devfile
    )
  end

  it "inserts volume" do
    invoke_insert

    expect(input_volumes.length).to eq(2)

    input_volumes => [
      {}, # existing fake element
      {
        name: volume_name,
        projected: {
          defaultMode: mode,
          sources: [
            {
              configMap: {
                name: configmap_name
              }
            }
          ]
        }
      }
    ]

    expect(volume_name)
      .to eq(create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME)
    expect(mode).to eq(create_constants_module::WORKSPACE_SCRIPTS_VOLUME_DEFAULT_MODE)
    expect(configmap_name).to eq(name)
  end

  it "inserts volumeMounts" do
    invoke_insert

    expect(input_containers.all? { |c| c[:volumeMounts].length == 2 }).to be true

    input_containers => [
      {
        volumeMounts: [
          {}, # existing fake element
          inserted_mount_1
        ]
      },
      {
        volumeMounts: [
          {}, # existing fake element
          inserted_mount_2
        ]
      }
    ]

    expected_mount = {
      name: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_NAME,
      mountPath: create_constants_module::WORKSPACE_SCRIPTS_VOLUME_PATH
    }

    expect(inserted_mount_1).to eq(expected_mount)
    expect(inserted_mount_2).to eq(expected_mount)
  end
end
