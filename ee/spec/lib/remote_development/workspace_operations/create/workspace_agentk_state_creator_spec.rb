# frozen_string_literal: true

require "spec_helper"

# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::WorkspaceAgentkStateCreator, feature_category: :workspaces do
  include ResultMatchers

  include_context "with remote development shared fixtures"

  let(:workspace_name) { "workspace-991-990-fedcba" }
  let(:workspace) { create(:workspace, :without_workspace_agentk_state, name: workspace_name) }
  let(:expected_desired_config_json) { desired_config.as_json.fetch("desired_config_array") }
  let(:logger) { instance_double(RemoteDevelopment::Logger) }
  let(:desired_config) do
    ::RemoteDevelopment::WorkspaceOperations::DesiredConfig.new(desired_config_array: create_desired_config_array)
  end

  let(:context) do
    {
      desired_config: desired_config,
      workspace: workspace,
      logger: logger
    }
  end

  subject(:result) do
    described_class.create(context) # rubocop:disable Rails/SaveBang -- This is not an ActiveRecord method
  end

  it "persists the record and returns nil" do
    expect { result }.to change { RemoteDevelopment::WorkspaceAgentkState.count }

    expect(RemoteDevelopment::WorkspaceAgentkState.last)
      .to have_attributes(
        desired_config: expected_desired_config_json,
        workspace_id: workspace.id,
        project_id: workspace.project.id
      )

    expect(result).to eq(Gitlab::Fp::Result.ok(context))
  end

  context "when there are errors persisting the record" do
    it "returns wraps the database error in the Fp::Result error" do
      fake_errors = instance_double(ActiveModel::Errors, present?: true)
      fake_state = instance_double(RemoteDevelopment::WorkspaceAgentkState, errors: fake_errors)
      allow(RemoteDevelopment::WorkspaceAgentkState).to receive(:create!).and_return(fake_state)

      expect(result).to eq(
        Gitlab::Fp::Result.err(
          RemoteDevelopment::Messages::WorkspaceAgentkStateCreateFailed.new({ errors: fake_errors, context: context })
        )
      )
    end
  end

  context "when desired_config has errors" do
    before do
      allow(logger).to receive(:error)
      allow(desired_config).to receive(:valid?).and_return(false)
      allow(desired_config).to(
        receive_message_chain(:errors, :full_messages)
          .and_return(["cannot be nil", "has some issue"])
      )
    end

    it "logs an error message" do
      result

      expect(desired_config).to have_received(:valid?)
      expect(logger).to have_received(:error).with(
        hash_including(
          message: "desired_config is invalid",
          error_type: "workspace_agentk_state_error",
          workspace_id: workspace.id,
          validation_error: ["cannot be nil", "has some issue"]
        )
      )
    end
  end
end
