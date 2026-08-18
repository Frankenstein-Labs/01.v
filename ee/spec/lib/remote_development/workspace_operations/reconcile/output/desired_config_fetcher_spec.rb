# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are Minitest, not FactoryBot
RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Output::DesiredConfigFetcher, feature_category: :workspaces do
  let(:logger) { instance_double(RemoteDevelopment::Logger) }

  # NOTE: We are intentionally using `let` instead of `let_it_be` here. There are some subtle
  #       test- and fixture-ordering gotchas with the creation of the associated
  #       workspace_agentk_state by FactoryBot.
  let(:workspace) { create(:workspace) }
  let(:expected_desired_config_array) { workspace.workspace_agentk_state.desired_config }
  let(:expected_desired_config) do
    RemoteDevelopment::WorkspaceOperations::DesiredConfig.new(desired_config_array: expected_desired_config_array)
  end

  # noinspection RubyMismatchedArgumentType -- We are intentionally passing a double for logger
  subject(:desired_config) { described_class.fetch(workspace: workspace, logger: logger) }

  it "fixture sanity check" do
    # There are some subtle gotchas with the creation of the associated workspace_agentk_state
    # by FactoryBot. This test ensures that it was correctly created and associated
    expect(workspace.workspace_agentk_state).not_to be_nil
    expect(workspace.workspace_agentk_state).to be_valid
    expect(workspace).to be_valid
  end

  describe "#fetch" do
    # TODO: remove this 'let' after a successful shadow run. Issue - https://gitlab.com/gitlab-org/gitlab/-/issues/551935
    let(:generate_new_desired_config_method) { :generate_new_desired_config }

    it "returns desired_config" do
      expect(desired_config).to eq(expected_desired_config)
    end

    describe "when persisted desired_config_array is invalid" do
      before do
        workspace.workspace_agentk_state.update_attribute(:desired_config, "invalid json")
      end

      it "raises an error" do
        expect { desired_config }.to raise_error(ActiveModel::ValidationError)
      end
    end

    # TODO: remove this expectation after a successful shadow run. Issue - https://gitlab.com/gitlab-org/gitlab/-/issues/551935
    it "does not call RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main.main" do
      expect(described_class).not_to receive(generate_new_desired_config_method)
      desired_config
    end

    # TODO: remove this context after a successful shadow run. Issue - https://gitlab.com/gitlab-org/gitlab/-/issues/551935
    context "when workspace_agentk_state does not exist" do
      let(:expected_desired_config) do
        RemoteDevelopment::WorkspaceOperations::DesiredConfig.new(desired_config_array: [])
      end

      let(:result) { { desired_config: expected_desired_config } }
      let(:expected_context) do
        {
          params: {
            agent: workspace.agent
          },
          workspace: workspace,
          logger: logger
        }
      end

      before do
        allow(workspace).to receive(:workspace_agentk_state).and_return(nil)
      end

      it "calls RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main.main" do
        expect(described_class).to receive(generate_new_desired_config_method)
        desired_config
      end

      it "returns desired_config from Create::DesiredConfig::Main" do
        expect(RemoteDevelopment::WorkspaceOperations::Create::DesiredConfig::Main)
          .to receive(:main).with(expected_context) { result }
        expect(desired_config).to eq(expected_desired_config)
      end
    end
  end
end
