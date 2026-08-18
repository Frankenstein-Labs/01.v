# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::InternalPoststartCommandsInserter, feature_category: :workspaces do
  include_context "with remote development shared fixtures"

  let(:input_processed_devfile) do
    read_devfile("example.container-commands-updated-devfile.yaml.erb")
  end

  let(:expected_processed_devfile_name) { "example.internal-poststart-commands-inserted-devfile.yaml.erb" }
  let(:expected_processed_devfile) { read_devfile(expected_processed_devfile_name) }

  let(:project_path) { "test-project" }
  let(:project) do
    http_url_to_repo = "#{root_url}test-group/#{project_path}.git"
    instance_double("Project", path: project_path, http_url_to_repo: http_url_to_repo) # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  end
  let(:agent) { instance_double("Clusters::Agent") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper

  let(:context) do
    {
      params: {
        agent: agent,
        project: project,
        project_ref: "master"
      },
      processed_devfile: input_processed_devfile,
      tools_dir: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
        "#{create_constants_module::TOOLS_DIR_NAME}",
      volume_mounts: {
        data_volume: {
          path: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
        }
      }
    }
  end

  let(:clone_command) do
    returned_value[:processed_devfile][:commands].find do |cmd|
      cmd[:id] == "gl-clone-project-command"
    end
  end

  let(:clone_unshallow_command) do
    returned_value[:processed_devfile][:commands].find do |cmd|
      cmd[:id] == "gl-clone-unshallow-command"
    end
  end

  let(:start_agentw) { false }

  subject(:returned_value) do
    described_class.insert(context)
  end

  before do
    allow(described_class)
      .to receive(:start_agentw?)
            .and_return(start_agentw)
  end

  it "updates the devfile" do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end

  it "includes depth option in clone command" do
    expect(clone_command).not_to be_nil
    expect(clone_command[:exec][:commandLine]).to include("--depth 10")
  end

  it "includes unshallow logic in clone command" do
    command_line = clone_unshallow_command[:exec][:commandLine]

    expect(command_line).to include("git fetch --unshallow")
    expect(command_line).to include("clone-unshallow.log")
    expect(command_line).to include("git rev-parse --is-shallow-repository")
  end

  context "when start_agentw? returns true" do
    let(:start_agentw) { true }
    let(:expected_processed_devfile_name) do
      "example.internal-poststart-commands-inserted-devfile-with-agentw.yaml.erb"
    end

    it "updates the devfile" do
      expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
    end
  end
end
