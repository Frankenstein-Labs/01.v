# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::AgentPrerequisitesOperations::ResponseBuilder, feature_category: :workspaces do
  let(:shared_namespace) { "my-shared-namespace" }
  let(:workspaces_agent_config) do
    instance_double(
      "RemoteDevelopment::WorkspacesAgentConfig", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      shared_namespace: shared_namespace
    )
  end

  let(:agent) do
    instance_double(
      "Clusters::Agent", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      unversioned_latest_workspaces_agent_config: workspaces_agent_config
    )
  end

  let(:expected_response) do
    {
      shared_namespace: shared_namespace
    }
  end

  let(:context) { { agent: agent } }

  subject(:returned_value) do
    described_class.build(context)
  end

  it "builds the response" do
    returned_value => {
      response_payload: Hash => response_payload
    }

    expect(response_payload).to eq(expected_response)
  end
end
