# frozen_string_literal: true

require "spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceAgentkState, feature_category: :workspaces do
  # noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are Minitest, not FactoryBot
  let_it_be(:workspace) { create(:workspace) }

  subject(:workspace_agentk_state) do
    described_class.new(
      workspace: workspace,
      project: workspace.project,
      desired_config: Gitlab::Json.safe_parse(
        RemoteDevelopment::FixtureFileHelpers.read_fixture_file("example.desired_config.json")
      )
    )
  end

  describe "associations" do
    context "for belongs_to" do
      it { is_expected.to belong_to(:workspace) }
      it { is_expected.to belong_to(:project) }
    end

    context "when from factory" do
      subject(:created_workspace_agentk_state) do
        create(:workspace_agentk_state)
      end

      it "has correct associations from factory" do
        expect(created_workspace_agentk_state.workspace).not_to be_nil
        expect(created_workspace_agentk_state.project).not_to be_nil
        expect(created_workspace_agentk_state.project).to eq(created_workspace_agentk_state.workspace.project)
        expect(created_workspace_agentk_state).to be_valid
        created_desired_config = created_workspace_agentk_state.desired_config
        expect(created_desired_config).to be_a(Array)
        expect(created_desired_config).not_to be_nil
        expect(
          RemoteDevelopment::WorkspaceOperations::DesiredConfig.new(desired_config_array: created_desired_config)
        ).to be_valid
      end
    end
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:workspace_id) }
    it { is_expected.to validate_presence_of(:project_id) }
    it { is_expected.to validate_presence_of(:desired_config) }

    describe "desired_config validations" do
      using RSpec::Parameterized::TableSyntax

      shared_examples "invalid desired_config" do
        before do
          workspace_agentk_state.desired_config = desired_config
        end

        it "is invalid" do
          expect(workspace_agentk_state).to be_invalid
          expect(workspace_agentk_state.errors[:desired_config]).to include(expected_error)
        end
      end

      where(:desired_config, :expected_error) do
        # @formatter:off - RubyMine does not format table well
        { key: "value" } | "must be an array"
        "string"         | "must be an array"
        1                | "must be an array"
        []               | "can't be blank"
        # @formatter:on
      end

      with_them do
        it_behaves_like "invalid desired_config"
      end
    end
  end
end
