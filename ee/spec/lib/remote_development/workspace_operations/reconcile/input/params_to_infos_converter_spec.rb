# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsToInfosConverter, feature_category: :workspaces do
  let(:workspace_agent_info_hashes_from_params) do
    [
      {
        name: "workspace1"
      },
      {
        name: "workspace2"
      }
    ]
  end

  let(:expected_agent_info_1) do
    instance_double("RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo", name: "workspace1") # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  end

  let(:expected_agent_info_2) do
    instance_double("RemoteDevelopment::WorkspaceOperations::Reconcile::Input::AgentInfo", name: "workspace2") # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  end

  let(:context) { { workspace_agent_info_hashes_from_params: workspace_agent_info_hashes_from_params } }

  subject(:returned_value) do
    described_class.convert(context)
  end

  before do
    allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Input::Factory)
      .to receive(:build)
            .with(agent_info_hash_from_params: workspace_agent_info_hashes_from_params[0]) { expected_agent_info_1 }
    allow(RemoteDevelopment::WorkspaceOperations::Reconcile::Input::Factory)
      .to receive(:build)
            .with(agent_info_hash_from_params: workspace_agent_info_hashes_from_params[1]) { expected_agent_info_2 }
  end

  it "converts array of workspace agent info hashes from params into array of AgentInfo value objects" do
    expect(returned_value).to eq(
      context.merge(
        workspace_agent_infos_by_name: {
          workspace1: expected_agent_info_1,
          workspace2: expected_agent_info_2
        }
      )
    )
  end
end
