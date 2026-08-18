# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::KubernetesPoststartHookInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:processed_devfile) { example_processed_devfile }
  let(:devfile_commands) { processed_devfile.fetch(:commands) }
  let(:devfile_events) { processed_devfile.fetch(:events) }
  let(:legacy_poststart_container_command) { false }
  let(:input_containers) do
    deployment = create_deployment(
      include_scripts_resources: false,
      legacy_poststart_container_command: legacy_poststart_container_command
    )
    deployment => {
      spec: {
        template: {
          spec: {
            containers: Array => containers
          }
        }
      }
    }
    containers
  end

  let(:expected_containers) do
    deployment = create_deployment(
      include_scripts_resources: true,
      legacy_poststart_container_command: legacy_poststart_container_command
    )
    deployment => {
      spec: {
        template: {
          spec: {
            containers: Array => containers
          }
        }
      }
    }
    containers
  end

  subject(:invoke_insert) do
    described_class.insert(
      # pass input containers without resources for scripts added, then assert they get added by the described_class
      containers: input_containers,
      devfile_commands: devfile_commands,
      devfile_events: devfile_events,
      processed_devfile: processed_devfile
    )
  end

  shared_examples "successful insertion of postStart lifecycle hooks" do
    it "inserts postStart lifecycle hooks", :unlimited_max_formatted_output_length do
      invoke_insert

      expected_containers => [
        *_,
        {
          lifecycle: Hash => first_container_expected_lifecycle_hooks
        },
        *_
      ]

      input_containers => [
        *_,
        {
          lifecycle: Hash => first_container_updated_lifecycle_hooks
        },
        *_
      ]

      expect(first_container_updated_lifecycle_hooks).to eq(first_container_expected_lifecycle_hooks)
    end
  end

  it "has valid fixtures with no lifecycle in any input_containers" do
    expect(input_containers.any? { |c| c[:lifecycle] }).to be false
  end

  it_behaves_like "successful insertion of postStart lifecycle hooks"

  context "when legacy poststart scripts are used" do
    let(:legacy_poststart_container_command) { true }
    let(:processed_devfile) do
      yaml_safe_load_symbolized(
        read_devfile_yaml("example.legacy-poststart-in-container-command-processed-devfile.yaml.erb",
          is_legacy_poststart: true)
      )
    end

    it_behaves_like "successful insertion of postStart lifecycle hooks"
  end

  private

  # @param [Boolean] include_scripts_resources
  # # @param [Boolean] legacy_poststart_container_command
  # @return [Hash]
  def create_deployment(include_scripts_resources:, legacy_poststart_container_command:)
    workspace_deployment(
      workspace_name: "name",
      workspace_namespace: "namespace",
      include_scripts_resources: include_scripts_resources,
      legacy_poststart_container_command: legacy_poststart_container_command
    )
  end
end
