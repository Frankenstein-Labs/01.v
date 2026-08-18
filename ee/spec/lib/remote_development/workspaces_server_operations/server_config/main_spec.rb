# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe ::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::Main, feature_category: :workspaces do
  let(:context_passed_along_steps) { {} }
  let(:response_payload) do
    {
      api_external_url: "external url",
      oauth_client_id: "client id",
      oauth_redirect_url: "redirect url"
    }
  end

  let(:rop_steps) do
    [
      [::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationAttributesGenerator, :map],
      [::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::OauthApplicationEnsurer, :map],
      [::RemoteDevelopment::WorkspacesServerOperations::ServerConfig::ValuesExtractor, :map]
    ]
  end

  describe "happy path" do
    let(:context_passed_along_steps) do
      {
        ok_details: "Everything is OK!",
        response_payload: response_payload
      }
    end

    let(:expected_response) do
      {
        status: :success,
        payload: response_payload
      }
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.main(context_passed_along_steps)
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_context_passed_along_steps(context_passed_along_steps)
              .and_return_expected_value(expected_response)
    end
  end
end
