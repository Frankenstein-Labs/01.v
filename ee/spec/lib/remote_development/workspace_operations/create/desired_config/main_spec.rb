# frozen_string_literal: true

require "fast_spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main, :freeze_time, feature_category: :workspaces do
  let(:rop_steps) do
    [
      [RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::ConfigValuesExtractor, :map],
      [RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DevfileParserGetter, :map],
      [RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DesiredConfigYamlParser, :map],
      [RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DevfileResourceModifier, :map],
      [RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::DevfileResourceAppender, :map]
    ]
  end

  let(:workspace_agent) { instance_double("Clusters::Agent", id: 1) } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:workspaces_agent_config) { instance_double("RemoteDevelopment::WorkspacesAgentConfig") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:project) { instance_double("Project", path: "test-project") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:workspace) do
    instance_double(
      "RemoteDevelopment::Workspace", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      id: 1,
      name: "workspace-name",
      namespace: "workspace-namespace",
      workspaces_agent_config: workspaces_agent_config,
      desired_state_running?: true,
      project: project,
      processed_devfile: "---")
  end

  let(:logger) { instance_double("RemoteDevelopment::Logger") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper

  let(:parent_context) do
    {
      workspace: workspace,
      logger: logger,
      params: {
        agent: workspace_agent
      }
    }
  end

  let(:context_passed_along_steps) do
    {
      workspace_id: parent_context[:workspace].id,
      workspace_name: parent_context[:workspace].name,
      workspace_namespace: parent_context[:workspace].namespace,
      workspace_desired_state_is_running: true,
      workspaces_agent_id: 1,
      workspaces_agent_config: workspaces_agent_config,
      processed_devfile_yaml: parent_context[:workspace].processed_devfile,
      project_path: parent_context[:workspace].project.path,
      logger: logger,
      desired_config_array: []
    }
  end

  let(:desired_config_array) { [] }

  describe "happy path" do
    let(:expected_value) do
      parent_context.merge(
        desired_config: RemoteDevelopment::WorkspaceOperations::DesiredConfig.new(
          desired_config_array: desired_config_array
        )
      )
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.main(parent_context)
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_context_passed_along_steps(context_passed_along_steps)
              .and_return_expected_value(expected_value)
    end
  end
end
