# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::ValuesExtractor, feature_category: :workspaces do
  let(:workspaces_oauth_application) do
    instance_double(
      "Doorkeeper::Application", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
      uid: "test_client_id",
      redirect_uri: "https://host:3000/-/kubernetes-agent/workspaces/oauth/redirect"
    )
  end

  let(:context) do
    {
      api_external_url: "https://host:3000/-/kubernetes-agent/workspaces",
      workspaces_oauth_application: workspaces_oauth_application
    }
  end

  let(:expected_result) do
    {
      response_payload: {
        api_external_url: "https://host:3000/-/kubernetes-agent/workspaces",
        oauth_client_id: "test_client_id",
        oauth_redirect_url: "https://host:3000/-/kubernetes-agent/workspaces/oauth/redirect"
      }
    }
  end

  subject(:result) { described_class.extract(context) }

  it "returns expected result" do
    expect(result).to eq(expected_result)
  end
end
