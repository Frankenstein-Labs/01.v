# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Input::ParamsExtractor, feature_category: :workspaces do
  let(:agent) { instance_double("Clusters::Agent") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  let(:original_params) do
    {
      "update_type" => "full",
      "workspace_agent_infos" => [
        {
          "name" => "my-workspace",
          "actual_state" => "unknown"
        }
      ]
    }
  end

  let(:context) do
    {
      agent: agent,
      original_params: original_params,
      existing_symbol_key_entry: "entry1",
      existing_string_key_entry: "entry2"
    }
  end

  subject(:returned_value) do
    described_class.extract(context)
  end

  it "extracts and flattens agent and params contents to top level and deep symbolizes keys" do
    expect(returned_value).to eq(
      {
        agent: agent,
        update_type: "full",
        original_params: original_params,
        workspace_agent_info_hashes_from_params: [
          {
            name: "my-workspace",
            actual_state: "unknown"
          }
        ],
        existing_symbol_key_entry: "entry1",
        existing_string_key_entry: "entry2"
      }
    )
  end
end
