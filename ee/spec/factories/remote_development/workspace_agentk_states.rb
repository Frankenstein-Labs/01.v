# frozen_string_literal: true

FactoryBot.define do
  factory :workspace_agentk_state, class: "RemoteDevelopment::WorkspaceAgentkState" do
    # noinspection RailsParamDefResolve -- RubyMine flags this as requiring a hash, but a symbol is a valid option
    association :workspace, :without_workspace_agentk_state

    desired_config do
      # NOTE: This desired_config fixture has hardcoded data, and the IDs/names/values will not match the
      #       workspace's actual data. If you want a realistic desired_config which matches a workspace, use the
      #       workspace factory to create a workspace and get its associated workspace_agentk_state.desired_config
      Gitlab::Json.safe_parse(RemoteDevelopment::FixtureFileHelpers.read_fixture_file("example.desired_config.json"))
    end

    before(:create) do |workspace_agentk_state, _|
      unless workspace_agentk_state.project
        workspace_project = workspace_agentk_state.workspace.project

        raise unless workspace_project # ensure that we never set a nil project - it can happen in some cases

        workspace_agentk_state.project = workspace_project
      end
    end
  end
end
